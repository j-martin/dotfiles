local audio = require('hs.audiodevice')
local spotify = require('hs.spotify')
local alert = require('hs.alert')
local application = require "hs.application"
local watcher = require "hs.caffeinate.watcher"
local headphones_watcher = require "audio/headphones_watcher"

local mod = {}

function mod.changeVolume(inc)
  return function ()
    local device = audio.defaultOutputDevice()
    local value = math.ceil(device:volume() + inc)
    if value <= 0 then
      device:setMuted(true)
      device:setVolume(0)
      alert.show('Muted')
    else
      device:setMuted(false)
      device:setVolume(value)
      alert.show('Volume: ' .. tostring(value) .. ' %' )
    end
  end
end

function mod.setVolume(value)
  return function ()
    local device = audio.defaultOutputDevice()
    device:setMuted(false)
    device:setVolume(value)
    alert.show('Volume: ' .. tostring(value) .. ' %' )
  end
end

function mod.open()
  application.launchOrFocus('Spotify')
end

local function callAndDisplay(fn)
  return function ()
    fn()
    spotify.displayCurrentTrack()
  end
end

mod.next = callAndDisplay(spotify.next)
mod.previous = callAndDisplay(spotify.previous)
mod.current = spotify.displayCurrentTrack

function mod.playpause()
  alert.show('Play/Pause')
  spotify.playpause()
end

local function parseEvent(event)
  if event == watcher.screensDidLock then
    spotify.pause()
  end
end

function mod.init()
  watcher.new(parseEvent):start()
  headphones_watcher.init()
end

return mod
