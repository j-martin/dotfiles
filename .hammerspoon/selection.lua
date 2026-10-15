local logger = hs.logger.new('selection', 'debug')

local mod = {}

local engines = {google = 'https://www.google.ca/search?q='}

-- Emacs does not expose its region through accessibility
local function selectedTextFromAccessibility()
  local app = hs.application.frontmostApplication()
  if app and app:name() == 'Emacs' then
    return nil
  end
  local element = hs.uielement.focusedElement()
  local ok, text = pcall(function()
    return element and element:selectedText()
  end)
  if ok and text and text ~= '' then
    return text
  end
  return nil
end

-- Only use real selections, never stale clipboard contents
local function selectedTextFromClipboard()
  local before = hs.pasteboard.changeCount()
  local initial = hs.pasteboard.readString()
  hs.eventtap.keyStroke({'cmd'}, 'c')
  hs.timer.usleep(150 * 1000)
  if hs.pasteboard.changeCount() == before then
    logger.d('Nothing copied, nothing is selected.')
    return ''
  end
  local text = hs.pasteboard.readString() or ''
  if initial then
    hs.pasteboard.setContents(initial)
  end
  return text
end

--- Returns the selected text of the focused app, or an empty string when nothing is selected.
function mod.getSelectedText()
  return selectedTextFromAccessibility() or selectedTextFromClipboard()
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
