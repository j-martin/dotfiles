local logger = hs.logger.new('selection', 'debug')

local mod = {}

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
