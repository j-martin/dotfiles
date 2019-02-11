local uielement = require "hs.uielement"
local timer = require "hs.timer"
local pasteboard = require "hs.pasteboard"
local http = require "hs.http"
local task = require "hs.task"
local eventtap = require "hs.eventtap"
local alert = require "hs.alert"
local window = require "hs.window"
local osascript = require "hs.osascript"
local logger = hs.logger.new('selection', 'debug')

local mod = {}

local engines = {
  google = 'https://www.google.ca/search?q=',
  googleLucky = 'https://www.google.ca/search?btnI&q='
}

local function selectedTextFromClipboard(currentApp)
  local selection
  local function getClipboard(initial, limit)
    if limit < 0 then return initial end
    eventtap.keyStroke({'cmd'}, 'c')
    timer.usleep(0.1 * 1000000)
    local selection = pasteboard.readString()
    if selection == initial and currentApp ~= 'Google Chrome' then
      logger.d('Same result. Retrying')
      return getClipboard(initial, limit - 1)
    else
      return selection
    end
  end

  local initial = pasteboard.readString()
  selection = getClipboard(initial, 10)
  logger.df('clipboard: %s', selection)
  pasteboard:setContents(initial)
  return selection
end

function mod.getSelectedText()
  local currentApp = window.focusedWindow():application():name()
  local element  = uielement.focusedElement()
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
  task.new('/usr/bin/open', nil, function() end, {url}):start()
end

local function query(url, text)
  openUrl(url .. http.encodeForQuery(text))
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
  local content = pasteboard.getContents()
  alert("Pasting/Typing: '" .. content .. "'")
  eventtap.keyStrokes(content)
end

local function round(number)
  return tostring(math.floor(number))
end

function mod.epochSinceNow(text)
  local initial = timer.secondsSinceEpoch()
  local selection = tonumber(text or mod.getSelectedText())

  if selection > 1000000000000 then
    selection = selection / 1000
  end

  local diff = initial - selection
  alert.show(
    round(diff / 60) .. ' mins / ' ..
      round(diff / 60 / 60) .. ' hours / ' ..
      round(diff / 60 / 60 / 24) .. ' days / ' ..
      round(diff / 60 / 60 / 24 / 30) .. ' months ago'
  )
end

return mod
