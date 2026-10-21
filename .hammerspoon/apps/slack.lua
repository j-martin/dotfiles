local logger = hs.logger.new('slack', 'info')
local utils = require 'apps/utils'

local mod = {}

mod.name = 'Slack'
mod.bundleId = 'com.tinyspeck.slackmacgap'

-- Config example:
-- ~/.private/hammerspoon.json
-- {
--  "slackTeamMapping": {
--    "team1": "T00000000",
--    "team2": "T11111111"
--  }
--}

mod.teamMapping = {
  -- slack domain (with or without '.slack.com') = "teamId"
  -- example:
  afakecompany = 'T00000000',
}

local prefixMapping = {
  C = 'channel',
  DA = 'user',
}

local function match(haystack, patternPrefix, pattern)
  local result = string.match(haystack, patternPrefix .. pattern)
  if not result then
    return nil
  end
  return result:sub(string.len(patternPrefix) + 1, -1)
end

--- Converts a https://<domain>.slack.com/archives/... URL to a slack:// deep link, or nil if it cannot be inferred.
-- e.g. https://xxxxxxxxx.slack.com/archives/C019DD3QJKY/p1639615885056700?thread_ts=1639615239.055000&cid=C019DD3QJKY
--   -> slack://channel?team=T00000000&id=C019DD3QJKY&message=1639615885.056700&thread_ts=1639615239.055000&cid=...
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
local function cleanTitle(title)
  return (title:gsub('^%*%s*', ''):gsub('%s+%-%s+Slack$', ''):gsub('%s+%-%s+%d+ new items?$', ''))
end

local function permalink(element)
  if element:attributeValue('AXRole') ~= 'AXLink' then
    return nil
  end
  local url = element:attributeValue('AXURL')
  url = type(url) == 'table' and url.url or nil
  return url and url:match('^https://[%w%-]+%.slack%.com/archives/%w+/p%d+') and url or nil
end

-- Distinct message permalinks under `element`, stopping once more than `limit` are found
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

--- Loads the team mapping from ~/.private/hammerspoon.json.
function mod.init()
  local privateConfigPath = os.getenv('HOME') .. '/.private/hammerspoon.json'
  if hs.fs.attributes(privateConfigPath) then
    logger.f("Loading private config from '%s'...", privateConfigPath)
    mod.teamMapping = hs.json.read(privateConfigPath).slackTeamMapping or mod.teamMapping
  end
end

return mod
