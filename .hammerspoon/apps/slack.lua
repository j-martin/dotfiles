local logger = hs.logger.new('slack', 'info')
local utils = require 'apps/utils'
local privateConfig = require 'utils/private_config'

---@class SlackApp
---@field name string
---@field bundleId string
---@field teamMapping table<string, string>
---@field deepLink fun(url: string, encodedParams: string): string|nil
---@field messageUrl fun(element: hs.axuielement): string|nil
---@field context fun(window: hs.window): table<string, string>|nil
---@field todosWindow fun(): hs.window|nil
---@field todos fun(window: hs.window): SlackTodos|nil
---@field completeTodo fun(window: hs.window, key: string, callback: fun(ok: boolean, err: string|nil))
---@field hoverTimer hs.timer|nil
---@field init fun()
local mod = {}

---@class SlackTodo
---@field key string Channel and message timestamp, e.g. "C0A439Q0PNG-1793123686.123989", else Slack's row id.
---@field text string
---@field author string|nil
---@field where string|nil Channel or conversation name.
---@field due string|nil As shown by Slack, e.g. "Tomorrow at 10:54".
---@field url string|nil

---@class SlackTodos
---@field todos SlackTodo[]
---@field complete boolean False when Slack counts more in progress to-dos than were read, e.g. not rendered yet.

mod.name = 'Slack'
mod.bundleId = 'com.tinyspeck.slackmacgap'

-- Slack domain (with or without '.slack.com') -> team ID, from the private config `slackTeamMapping`
mod.teamMapping = {}

local prefixMapping = {
  C = 'channel',
  DA = 'user',
}

---@param haystack string
---@param patternPrefix string
---@param pattern string
---@return string|nil
local function match(haystack, patternPrefix, pattern)
  local result = string.match(haystack, patternPrefix .. pattern)
  if not result then
    return nil
  end
  return result:sub(string.len(patternPrefix) + 1, -1)
end

--- Converts a https://<domain>.slack.com/archives/... URL to a slack:// deep link, or nil if it cannot be inferred.
---@param url string
---@param encodedParams string
---@return string|nil
function mod.deepLink(url, encodedParams)
  local teamId = nil
  for domain, value in pairs(mod.teamMapping) do
    if url:match('^https://' .. domain .. '.*') then
      teamId = value
    end
  end

  local urlPrefix = nil
  local itemId = nil
  for key, value in pairs(prefixMapping) do
    itemId = match(url, 'slack.com/archives/', key .. '%w+')
    if itemId then
      urlPrefix = value
      break
    end
  end

  local messageId = match(url, '/p', '%d+')
  if messageId then
    messageId = messageId:sub(0, 10) .. '.' .. messageId:sub(11, -1)
  end

  logger.i(urlPrefix, teamId, itemId, messageId)
  if not urlPrefix or not teamId then
    return nil
  end
  return 'slack://'
    .. urlPrefix
    .. '?team='
    .. teamId
    .. '&id='
    .. itemId
    .. '&message='
    .. (messageId or '')
    .. '&'
    .. encodedParams
end

-- e.g. "* Mike (DM) - Workspace - 2 new items - Slack" -> "Mike (DM) - Workspace"
---@param title string
---@return string
local function cleanTitle(title)
  return (title:gsub('^%*%s*', ''):gsub('%s+%-%s+Slack$', ''):gsub('%s+%-%s+%d+ new items?$', ''))
end

---@param element hs.axuielement
---@return string|nil
local function permalink(element)
  if element:attributeValue('AXRole') ~= 'AXLink' then
    return nil
  end
  local url = element:attributeValue('AXURL')
  url = type(url) == 'table' and url.url or nil
  return url and url:match('^https://[%w%-]+%.slack%.com/archives/%w+/p%d+') and url or nil
end

-- Distinct message permalinks under `element`, stopping once more than `limit` are found
---@param element hs.axuielement
---@param depth number
---@param limit number
---@param found table<string, any>
---@return table<string, any>
local function collectPermalinks(element, depth, limit, found)
  local url = permalink(element)
  if url and not found[url:match('^[^?]+')] then
    found[url:match('^[^?]+')] = url
    found.count = found.count + 1
  end
  if depth <= 0 or found.count > limit then
    return found
  end
  for _, child in ipairs(element:attributeValue('AXChildren') or {}) do
    collectPermalinks(child, depth - 1, limit, found)
    if found.count > limit then
      break
    end
  end
  return found
end

--- Returns the permalink of the message containing `element`, or nil when it is not inside a single message.
---@param element hs.axuielement
---@return string|nil
function mod.messageUrl(element)
  while element do
    local role = element:attributeValue('AXRole')
    if role == 'AXList' or role == 'AXWebArea' or role == 'AXWindow' then
      return nil
    end
    local found = collectPermalinks(element, 8, 1, { count = 0 })
    if found.count > 1 then
      return nil
    elseif found.count == 1 then
      for key, url in pairs(found) do
        if key ~= 'count' then
          return url
        end
      end
    end
    element = element:attributeValue('AXParent')
  end
  return nil
end

-- The message under the mouse, or else the keyboard focused one
---@param app hs.application
---@return string|nil
local function selectedMessageUrl(app)
  local hovered = hs.axuielement.systemElementAtPosition(hs.mouse.absolutePosition())
  local url = hovered and hovered:pid() == app:pid() and mod.messageUrl(hovered)
  if url then
    return url
  end
  local focused = hs.axuielement.applicationElement(app):attributeValue('AXFocusedUIElement')
  return focused and mod.messageUrl(focused) or nil
end

--- Returns the current channel, and the permalink of the hovered or focused message, else the channel URL.
---@param window hs.window
---@return table<string, string>|nil
function mod.context(window)
  local app = window:application()
  utils.enableManualAccessibility(app)
  local messageUrl = selectedMessageUrl(app)
  if messageUrl then
    return { title = cleanTitle(window:title()), url = messageUrl }
  end
  local webArea = utils.findElement(hs.axuielement.windowElement(window), utils.hasRole('AXWebArea'), 8)
  local url = webArea and webArea:attributeValue('AXURL')
  return { title = cleanTitle(window:title()), url = type(url) == 'table' and url.url or nil }
end

--- Returns the Slack window showing the To-dos tab, or nil. Its URL is checked, as the title
--- shows the conversation instead when a to-do is opened in the side panel.
---@return hs.window|nil
function mod.todosWindow()
  local app = hs.application.get(mod.bundleId)
  if not app then
    return nil
  end
  utils.enableManualAccessibility(app)
  for _, window in ipairs(app:allWindows()) do
    local webArea = utils.findElement(hs.axuielement.windowElement(window), utils.hasRole('AXWebArea'), 8)
    local url = webArea and webArea:attributeValue('AXURL')
    if type(url) == 'table' and url.url:match('^https://app%.slack%.com/client/%w+/to%-dos') then
      return window
    end
  end
  return nil
end

-- Message permalink, a https one when the workspace domain is known
---@param host string|nil e.g. "afakecompany.slack.com"
---@param teamId string|nil
---@param channel string
---@param ts string
---@return string|nil
local function todoUrl(host, teamId, channel, ts)
  if host then
    return 'https://' .. host .. '/archives/' .. channel .. '/p' .. ts:gsub('%.', '')
  end
  if teamId then
    return 'slack://channel?team=' .. teamId .. '&id=' .. channel .. '&message=' .. ts
  end
  return nil
end

-- Workspace domain of the window, from `mod.teamMapping` or else from a link on the page
---@param webArea hs.axuielement
---@param teamId string|nil
---@return string|nil
local function workspaceHost(webArea, teamId)
  for domain, value in pairs(mod.teamMapping) do
    if value == teamId then
      return domain:match('%.slack%.com$') and domain or (domain .. '.slack.com')
    end
  end
  local link = utils.findElement(webArea, function(element)
    local url = element:attributeValue('AXRole') == 'AXLink' and element:attributeValue('AXURL')
    return type(url) == 'table' and url.url:match('^https://[%w%-]+%.slack%.com/') ~= nil
  end, 30)
  return link and link:attributeValue('AXURL').url:match('^https://([%w%-]+%.slack%.com)/') or nil
end

-- e.g. "Reminder due Tomorrow at 10:54. jm. In ext-google-cloud. @alex To be clear…"
---@param row hs.axuielement
---@param host string|nil
---@param teamId string|nil
---@return SlackTodo
local function parseTodo(row, host, teamId)
  local id = row:attributeValue('AXDOMIdentifier') or ''
  local description = row:attributeValue('AXDescription') or ''
  local due, rest = description:match('^Reminder due (.-)%. (.*)$')
  rest = rest or description
  local author, where, text = rest:match('^(.-)%. In (.-)%. (.*)$')
  text = (text or rest):gsub('%s+Message from [^.]+%. At [^.]+%.$', '')
  local channel, ts = id:match('^(%w+)%-(%d+%.%d+)')
  return {
    key = channel and (channel .. '-' .. ts) or id,
    text = text,
    author = author,
    where = where,
    due = due,
    url = channel and todoUrl(host, teamId, channel, ts) or nil,
  }
end

---@param element hs.axuielement
---@return boolean
local function isTodoRow(element)
  local classes = element:attributeValue('AXDOMClassList')
  return type(classes) == 'table'
    and hs.fnutils.some(classes, function(class)
      return class:match('^todoRow') ~= nil
    end)
end

--- Reads the in progress to-dos shown by the To-dos tab of `window`.
---@param window hs.window
---@return SlackTodos|nil
function mod.todos(window)
  utils.enableManualAccessibility(window:application())
  local webArea = utils.findElement(hs.axuielement.windowElement(window), utils.hasRole('AXWebArea'), 8)
  if not webArea then
    return nil
  end
  local url = webArea:attributeValue('AXURL')
  local teamId = type(url) == 'table' and url.url:match('/client/(T%w+)/') or nil

  ---@param element hs.axuielement
  ---@return boolean
  local function isInProgress(element)
    local role = element:attributeValue('AXRole')
    return (role == 'AXList' and element:attributeValue('AXTitle') == 'In progress')
      or (role == 'AXButton' and (element:attributeValue('AXDescription') or ''):match('^In progress, %d+$') ~= nil)
  end
  local toggle = utils.findElement(webArea, isInProgress, 20)
  if not toggle then
    return nil
  end
  local parent = toggle:attributeValue('AXParent')
  ---@type number|nil
  local expected = nil
  local list = nil
  for _, child in ipairs(parent and parent:attributeValue('AXChildren') or {}) do
    local count = (child:attributeValue('AXDescription') or ''):match('^In progress, (%d+)$')
    if count then
      expected = tonumber(count)
    elseif child:attributeValue('AXRole') == 'AXList' and child:attributeValue('AXTitle') == 'In progress' then
      list = child
    end
  end

  local host = workspaceHost(webArea, teamId)
  ---@type SlackTodo[]
  local todos = {}
  for _, row in ipairs(list and list:attributeValue('AXChildren') or {}) do
    if isTodoRow(row) then
      table.insert(todos, parseTodo(row, host, teamId))
    end
  end
  return { todos = todos, complete = expected ~= nil and #todos == expected }
end

--- Marks the to-do of `key` complete in the To-dos tab of `window`. Its buttons only exist while
--- hovered, so the mouse is moved over the row for a moment, then put back.
---@param window hs.window
---@param key string
---@param callback fun(ok: boolean, err: string|nil)
function mod.completeTodo(window, key, callback)
  local row = utils.findElement(hs.axuielement.windowElement(window), function(element)
    local id = element:attributeValue('AXDOMIdentifier')
    return type(id) == 'string' and id:sub(1, #key + 1) == key .. '_' and isTodoRow(element)
  end, 30)
  if not row then
    callback(false, 'row not found')
    return
  end
  row:performAction('AXScrollToVisible')
  local frame = row:attributeValue('AXFrame')
  if not frame then
    callback(false, 'row has no frame')
    return
  end
  local point = { x = frame.x + frame.w - 60, y = frame.y + math.min(frame.h / 2, 15) }
  local under = hs.axuielement.systemElementAtPosition(point)
  if not under or under:pid() ~= window:application():pid() then
    callback(false, 'the row is covered by another window')
    return
  end
  local saved = hs.mouse.absolutePosition()
  hs.mouse.absolutePosition(point)
  mod.hoverTimer = hs.timer.doAfter(0.5, function()
    local button = utils.findElement(row, function(element)
      return element:attributeValue('AXRole') == 'AXButton'
        and element:attributeValue('AXDescription') == 'Mark complete'
    end, 10)
    local pressed = button and button:performAction('AXPress')
    hs.mouse.absolutePosition(saved)
    if pressed then
      callback(true, nil)
    else
      callback(false, 'Mark complete button not found')
    end
  end)
end

--- Loads the team mapping from the private config.
function mod.init()
  mod.teamMapping = privateConfig.get('slackTeamMapping') or mod.teamMapping
end

return mod
