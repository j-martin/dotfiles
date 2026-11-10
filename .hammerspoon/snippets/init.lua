-- Snippet expander: typed triggers expand in place, and a picker lists every snippet.
local logger = hs.logger.new('snippets', 'info')

local config = require 'config'
local matcher = require 'snippets/matcher'
local privateConfig = require 'utils/private_config'

---@class SnippetsModule
---@field snippets Snippet[]
local mod = {
  snippets = {},
}

-- Kept at module level so they are not garbage collected.
---@type hs.eventtap|nil
local tap = nil
---@type hs.timer|nil
local watchdog = nil
---@type hs.chooser|nil
local chooser = nil

---@type string
local buffer = ''
---@type integer
local maxLength = 0

local keyCodes = hs.keycodes.map
---@type table<integer, boolean>
local resetKeys = {
  [keyCodes['return']] = true,
  [keyCodes['padenter']] = true,
  [keyCodes['escape']] = true,
  [keyCodes['tab']] = true,
  [keyCodes['left']] = true,
  [keyCodes['right']] = true,
  [keyCodes['up']] = true,
  [keyCodes['down']] = true,
  [keyCodes['home']] = true,
  [keyCodes['end']] = true,
  [keyCodes['pageup']] = true,
  [keyCodes['pagedown']] = true,
}

--- Pastes `text` into the focused app, then restores the previous clipboard.
---@param text string
function mod.insert(text)
  local previous = hs.pasteboard.readAllData()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({ 'cmd' }, 'v', 0)
  hs.timer.doAfter(0.3, function()
    if previous and next(previous) then
      hs.pasteboard.writeAllData(previous)
    end
  end)
end

--- Deletes the typed trigger and inserts the snippet text, without the tap seeing its own keystrokes.
---@param snippet Snippet
local function expand(snippet)
  hs.timer.doAfter(0, function()
    if tap then
      tap:stop()
    end
    for _ = 1, utf8.len(snippet.trigger) or #snippet.trigger do
      hs.eventtap.keyStroke({}, 'delete', 0)
    end
    mod.insert(snippet.text)
    if tap then
      tap:start()
    end
  end)
end

-- Returning false lets every key through; expansion happens after the key is typed.
---@param event hs.eventtap.event
---@return boolean
local function onKeyDown(event)
  if hs.eventtap.isSecureInputEnabled() then
    buffer = ''
    return false
  end
  local flags = event:getFlags()
  local keyCode = event:getKeyCode()
  if flags.cmd or flags.ctrl or flags.alt or flags.fn or resetKeys[keyCode] then
    buffer = ''
    return false
  end
  if keyCode == keyCodes['delete'] then
    buffer = matcher.pop(buffer)
    return false
  end
  local char = event:getCharacters()
  if char == nil or char == '' then
    return false
  end
  buffer = matcher.push(buffer, char, maxLength)
  local snippet = matcher.findMatch(buffer, mod.snippets)
  if snippet then
    logger.df('Expanding %s', snippet.trigger)
    buffer = ''
    expand(snippet)
  end
  return false
end

--- Shows every snippet in a searchable list and pastes the one picked.
function mod.pick()
  local window = hs.window.focusedWindow()
  if chooser then
    chooser:delete()
  end
  chooser = hs.chooser.new(function(choice)
    if window then
      window:focus()
    end
    if choice then
      hs.timer.doAfter(0.2, function()
        mod.insert(choice.snippetText)
      end)
    end
  end)
  chooser:bgDark(true)
  chooser:placeholderText('Snippets')
  chooser:searchSubText(true)
  chooser:choices(hs.fnutils.map(mod.snippets, function(snippet)
    return {
      text = snippet.desc or snippet.trigger,
      subText = snippet.trigger .. '  ' .. snippet.text:gsub('%s+', ' '),
      snippetText = snippet.text,
    }
  end))
  chooser:show()
end

--- Loads the public and private snippets.
function mod.load()
  mod.snippets = matcher.merge(config.snippets or {}, privateConfig.get('snippets') or {})
  maxLength = matcher.maxTriggerLength(mod.snippets)
  logger.f('Loaded %d snippets', #mod.snippets)
end

--- Loads the snippets and starts expanding typed triggers.
function mod.init()
  mod.load()
  if tap then
    tap:stop()
  end
  if watchdog then
    watchdog:stop()
  end
  tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, onKeyDown)
  tap:start()
  -- macOS disables event taps that are too slow to answer.
  watchdog = hs.timer.doEvery(5, function()
    if tap and not tap:isEnabled() then
      logger.w('Snippet expander was disabled, restarting it')
      tap:start()
    end
  end)
end

return mod
