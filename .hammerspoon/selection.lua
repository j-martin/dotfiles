local uielement = require "hs.uielement"
local timer = require "hs.timer"
local pasteboard = require "hs.pasteboard"
local http = require "hs.http"
local task = require "hs.task"
local eventtap = require "hs.eventtap"
local alert = require "hs.alert"
local logger = hs.logger.new('selection', 'debug')

local mod = {}

local engines = {
  google = 'https://www.google.ca/search?q='
}

local function selectedTextFromClipboard()
  local current = pasteboard.readString()

  local clipboardDelay = 200000 -- 200ms

  eventtap.keyStroke({'cmd'}, 'c')
  timer.usleep(clipboardDelay)
  local selection = pasteboard.readString()
  if selection == current then
    logger.d('Same result. Retrying')
    timer.usleep(clipboardDelay)
    selection = pasteboard.readString()
  end

  logger.d(selection)
  pasteboard:setContents(current)
  return selection
end

local function selectedText()
  local selection  = uielement.focusedElement():selectedText()
  if not selection then
    return selectedTextFromClipboard()
  end

  return selection
end

local function openUrl(url)
  task.new('/usr/bin/open', logger.d, logger.d, {url}):start()
end

local function query(url, text)
  openUrl(url .. http.encodeForQuery(text))
end

local function google(text)
  query(engines['google'], text or selectedText())
end

function mod.actOn()
  local text = selectedText()
  if text:gmatch("https?://")() then
    openUrl(text)
  elseif text:gmatch("1%d%d%d%d%d%d%d%d%d+")() then
    mod.epochSinceNow(text)
  else
    google(text)
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
  local current = timer.secondsSinceEpoch()
  local selection = tonumber(text or selectedText())

  if selection > 1000000000000 then
    selection = selection / 1000
  end

  local diff = current - selection
  hs.alert(
    round(diff / 60) .. ' mins / ' ..
      round(diff / 60 / 60) .. ' hours / ' ..
      round(diff / 60 / 60 / 24) .. ' days / ' ..
      round(diff / 60 / 60 / 24 / 30) .. ' months ago'
  )
end

return mod
