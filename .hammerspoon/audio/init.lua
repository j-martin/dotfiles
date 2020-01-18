local audiodevice = require 'hs.audiodevice'
local spotify = require 'hs.spotify'
local alert = require 'hs.alert'
local application = require "hs.application"
local watcher = require "hs.caffeinate.watcher"
local headphones_watcher = require "audio/headphones_watcher"

local mod = {}

function mod.workSetup()
  local dac = audiodevice.findOutputByName('FiiO USB DAC-E10')
  dac:setDefaultOutputDevice()
  dac:setMuted(false)
  dac:setVolume(50)
  mod.muteSpeakers()
end

function mod.muteSpeakers()
  local speakers = audiodevice.findOutputByName('Built-in Output')
  if not speakers then
    return
  end
  speakers:setVolume(0)
  speakers:setMuted(true)
end

function mod.changeVolume(inc)
  return function()
    local device = audiodevice.defaultOutputDevice()
    local value = math.ceil(device:volume() + inc)
    if value <= 0 then
      device:setVolume(0)
      device:setMuted(true)
      alert.show('Muted')
    else
      device:setMuted(false)
      device:setVolume(value)
      alert.show('Volume: ' .. tostring(value) .. ' %')
    end
  end
end

function mod.setVolume(value)
  return function()
    local device = audiodevice.defaultOutputDevice()
    device:setMuted(false)
    device:setVolume(value)
    alert.show('Volume: ' .. tostring(value) .. ' %')
  end
end

function mod.open()
  application.launchOrFocus('Spotify')
end

local function callAndDisplay(fn)
  return function()
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
  function plugged()
    mod.muteSpeakers()
    local outputDevice = audiodevice.defaultOutputDevice()
    outputDevice:setMuted(false)
    outputDevice:setVolume(15)
  end

  function unplugged()
    mod.muteSpeakers()
    spotify.pause()
  end

  watcher.new(parseEvent):start()
  headphones_watcher.init(plugged, unplugged)
end

return mod
