local audio = require('hs.audiodevice')
local spotify = require('hs.spotify')
local alert = require('hs.alert')
local application = require "hs.application"

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

return mod
