local logger = hs.logger.new('selection', 'debug')
local apps = require 'apps'

local mod = {}

local llmPath = apps.getExecPath('llm')

local engines = {google = 'https://www.google.ca/search?q='}

local function selectedTextFromClipboard(currentApp)
  local selection
  local function getClipboard(initial, retries)
    if retries < 0 then
      return initial
    end
    hs.timer.usleep(0.1 * 1000000)
    local selection = hs.pasteboard.readString()
    if selection == initial and currentApp ~= 'Brave Browser' then
      logger.d('Same result. Retrying')
      return getClipboard(initial, retries - 1)
    else
      return selection
    end
  end

  local initial = hs.pasteboard.readString()
  hs.eventtap.keyStroke({'cmd'}, 'c')
  selection = getClipboard(initial, 3)
  logger.df('clipboard: %s', selection)
  hs.pasteboard:setContents(initial)
  return selection
end

function mod.getSelectedText()
  local currentWindow = hs.window.focusedWindow()
  local currentApp = 'unknown'
  if currentWindow then
    currentApp = currentWindow:application():name()
  end
  local element = hs.uielement.focusedElement()
  local selection

  if element then
    selection = element:selectedText()
  end

  if not selection or currentApp == 'Emacs' then
    return selectedTextFromClipboard(currentApp)
  end

  return selection
end

local function openUrl(url)
  hs.task.new('/usr/bin/open', nil, function()
  end, {url}):start()
end

local function query(url, text)
  openUrl(url .. hs.http.encodeForQuery(text))
end

local function google(text, engine)
  query(engines[engine], text or mod.getSelectedText())
end

function mod.actOn(engine)
  return function()
    local text = mod.getSelectedText()
    if text:gmatch("https?://")() then
      openUrl(text)
      -- TODO: Cleanup silly regex
    elseif text:gmatch("1%d%d%d%d%d%d%d%d%d+")() then
      mod.epochSinceNow(text)
    else
      google(text, engine)
    end
  end
end

-- copyForReplace copies the current selection to the clipboard so it can later be
-- replaced with a transformed version. If nothing is selected it falls back to
-- selecting the entire focused field. Returns the copied text and the pasteboard's
-- prior contents so the caller can restore them once the replacement is done.
local function copyForReplace()
  local initial = hs.pasteboard.readString() or ''
  hs.eventtap.keyStroke({'cmd'}, 'c')
  hs.timer.usleep(150 * 1000)
  local selected = hs.pasteboard.readString() or ''
  if selected == initial then
    hs.eventtap.keyStroke({'cmd'}, 'a')
    hs.timer.usleep(50 * 1000)
    hs.eventtap.keyStroke({'cmd'}, 'c')
    hs.timer.usleep(150 * 1000)
    selected = hs.pasteboard.readString() or ''
  end
  return selected, initial
end

-- transformSelection returns a callback that pipes the current selection through
-- the `llm` CLI in the given mode ("grammar" or "smoothen") and pastes the result
-- back over the selection. When no text is selected the whole focused field is used.
function mod.transformSelection(llmMode)
  return function()
    local text, initial = copyForReplace()
    if not text or text == '' then
      hs.alert.show('llm ' .. llmMode .. ': nothing to transform')
      return
    end

    local messageId = hs.alert.show('llm ' .. llmMode .. ' running do not change focus…', nil, nil, 'infinite')
    logger.df('llm %s input=%d chars via %s', llmMode, #text, llmPath)
    local onDone = function(exitCode, stdOut, stdErr)
      hs.alert.closeSpecific(messageId)
      hs.alert.show('llm done', nil, nil, 1)
      logger.df('llm exit=%s stdout=%d chars stderr=%s',
                tostring(exitCode), #(stdOut or ''), stdErr or '')
      if exitCode ~= 0 then
        hs.alert.show('llm failed (' .. tostring(exitCode) .. '): ' .. ((stdErr or ''):sub(1, 80)))
        return
      end
      local result = (stdOut or ''):gsub('%s+$', '')
      if result == '' then
        hs.alert.show('llm returned empty output')
        return
      end
      hs.pasteboard.setContents(result)
      hs.timer.usleep(30 * 1000)
      hs.eventtap.keyStroke({'cmd'}, 'v')
      hs.timer.doAfter(0.6, function()
        hs.pasteboard.setContents(initial)
      end)
    end
    hs.task.new(llmPath, onDone, {llmMode, text}):start()
  end
end

function mod.paste()
  local content = hs.pasteboard.getContents()
  hs.alert("Pasting/Typing: '" .. content .. "'")
  for line in content:gmatch("[^\r\n]+") do
    hs.eventtap.keyStrokes(line)
    hs.eventtap.keyStroke({}, "return")
  end
end

local function round(number)
  return tostring(math.floor(number))
end

function mod.epochSinceNow(text)
  local initial = hs.timer.secondsSinceEpoch()
  local selection = tonumber(text or mod.getSelectedText())

  if selection > 1000000000000 then
    selection = selection / 1000
  end

  local diff = initial - selection
  hs.alert.show(round(diff / 60) .. ' mins / ' .. round(diff / 60 / 60) .. ' hours / ' .. round(diff / 60 / 60 / 24)
               .. ' days / ' .. round(diff / 60 / 60 / 24 / 30) .. ' months ago')
end

return mod
