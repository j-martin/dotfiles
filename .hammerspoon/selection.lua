local uielement = require "hs.uielement"
local timer = require "hs.timer"
local pasteboard = require "hs.pasteboard"
local http = require "hs.http"
local task = require "hs.task"
local eventtap = require "hs.eventtap"
local timer = require "hs.timer"

local mod = {}

local engines = {
  google = 'https://www.google.ca/search?q='
}

local function selectedTextFromClipboard()
  local current = pasteboard.readString()

  eventtap.keyStroke({'cmd'}, 'c')
  timer.usleep(200000)
  local selection = pasteboard.readString()

  pasteboard:setContents(current)
  return selection
end

function mod.selectedText()
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

function mod.googleSelectedText()
  query(engines['google'], mod.selectedText())
end

local function round(number)
  return tostring(math.floor(number))
end

function mod.epochSinceNow()
  local current = timer.secondsSinceEpoch()
  local selection = tonumber(mod.selectedText())

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
