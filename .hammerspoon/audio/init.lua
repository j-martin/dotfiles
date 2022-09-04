local audiodevice = require 'hs.audiodevice'
local spotify = require 'hs.spotify'
local alert = require 'hs.alert'
local application = require "hs.application"
local watcher = require "hs.caffeinate.watcher"
local headphones_watcher = require "audio/headphones_watcher"

local mod = {}

dacName = 'FiiO USB DAC-E10'

mod.volumes = {}
mod.volumes[dacName] = 100

inputDevicePriority = {
  "Samson Q2U Microphone",
  "MacBook Pro Microphone"
}

outputDevicePriority = {
  "WH-1000XM3",
  dacName
}

function mod.setDefaultInputDevice()
  for _, deviceName in ipairs(inputDevicePriority) do
    device = audiodevice.findDeviceByName(deviceName)
    if device then
      if device:setDefaultInputDevice() then
        alert.show("Input Device: " .. deviceName)
        return
      end
    end
  end
end

function mod.setDefaultOutputDevice()
  for _, deviceName in ipairs(outputDevicePriority) do
    alert.show(deviceName)
    device = audiodevice.findDeviceByName(deviceName)
    if audiodevice.defaultOutputDevice() == device then
      alert.show('x')
    elseif device then
      device:setDefaultOutputDevice()
      alert.show("Output Device: " .. deviceName)
      return
    end
  end
end

function mod.workSetup()
  local dac = audiodevice.findOutputByName(dacName)
  dac:setDefaultOutputDevice()
  dac:setMuted(false)
  dac:setVolume(dacVolume)
  mod.muteSpeakers()
end

function mod.muteSpeakers(name)
  local speakers = audiodevice.findOutputByName(name)
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
      mod.setVolume(value)
    end
  end
end

function mod.setVolume(value)
  return function()
    local device = audiodevice.defaultOutputDevice()
    local deviceName = device:name()
    if value == 'default' then
      finalValue = mod.volumes[deviceName] or 15
    end
    device:setBalance(0.5)
    device:setMuted(false)
    device:setVolume(finalValue)
    alert.show('Volume for ' .. deviceName .. ' set to ' .. tostring(finalValue) .. ' %')
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
    mod.muteSpeakers('Built-in Output')
    mod.muteSpeakers('MacBook Pro Speakers')
    local outputDevice = audiodevice.defaultOutputDevice()
    outputDevice:setMuted(false)
    value = mod.volumes[device:name()] or 15
    outputDevice:setVolume(value)
  end

  function unplugged()
    mod.muteSpeakers('Built-in Output')
    mod.muteSpeakers('MacBook Pro Speakers')
    spotify.pause()
    mod.setDefaultInputDevice()
  end

  watcher.new(parseEvent):start()
  headphones_watcher.init(plugged, unplugged)
end

return mod
