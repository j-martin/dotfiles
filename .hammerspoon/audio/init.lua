local headphones_watcher = require "audio/headphones_watcher"

local mod = {}

dacName = 'FiiO USB DAC-E10'
appleUSBWithDT1990Pro = 'USB-C to 3.5mm Headphone Jack Adapter'

mod.volumes = {}
mod.volumes[dacName] = 100
mod.volumes[appleUSBWithDT1990Pro] = 20

inputDevicePriority = {
  "RØDE VideoMic GO II",
  "Samson Q2U Microphone",
  "MacBook Pro Microphone",
}

outputDevicePriority = {
  "WH-1000XM3",
  appleUSBWithDT1990Pro,
  dacName
}

function mod.setDefaultInputDevice()
  for _, deviceName in ipairs(inputDevicePriority) do
    device = hs.audiodevice.findDeviceByName(deviceName)
    if device then
      if device:setDefaultInputDevice() then
        hs.alert.show("Input Device: " .. deviceName)
        return
      end
    end
  end
end

function mod.setDefaultOutputDevice()
  for _, deviceName in ipairs(outputDevicePriority) do
    hs.alert.show(deviceName)
    device = hs.audiodevice.findDeviceByName(deviceName)
    if hs.audiodevice.defaultOutputDevice() == device then
      hs.alert.show('x')
    elseif device then
      device:setDefaultOutputDevice()
      hs.alert.show("Output Device: " .. deviceName)
      return
    end
  end
end

function mod.workSetup()
  local dac = hs.audiodevice.findOutputByName(dacName)
  dac:setDefaultOutputDevice()
  dac:setMuted(false)
  dac:setVolume(mod.volumes[dacName])
  mod.muteSpeakers()
end

function mod.muteSpeakers(name)
  local speakers = hs.audiodevice.findOutputByName(name)
  if not speakers then
    return
  end
  speakers:setVolume(0)
  speakers:setMuted(true)
end

function mod.changeVolume(inc)
  return function()
    local device = hs.audiodevice.defaultOutputDevice()
    local value = math.ceil(device:volume() + inc)
    if value <= 0 then
      device:setVolume(0)
      device:setMuted(true)
      hs.alert.show('Muted')
    else
      device:setMuted(false)
      mod.setVolume(value)()
    end
  end
end

function mod.setVolume(value)
  return function()
    local finalValue = value

    local device = hs.audiodevice.defaultOutputDevice()
    local deviceName = device:name()
    if value == 'default' then
      finalValue = mod.volumes[deviceName] or 15
    end
    device:setBalance(0.5)
    device:setMuted(false)

    device:setVolume(finalValue)
    hs.alert.show('Volume for ' .. deviceName .. ' set to ' .. tostring(finalValue) .. ' %')
  end
end

function mod.open()
  hs.application.launchOrFocus('Spotify')
end

local function callAndDisplay(fn)
  return function()
    fn()
    hs.spotify.displayCurrentTrack()
  end
end

mod.next = callAndDisplay(hs.spotify.next)
mod.previous = callAndDisplay(hs.spotify.previous)
mod.current = hs.spotify.displayCurrentTrack

function mod.playpause()
  hs.alert.show('Play/Pause')
  hs.spotify.playpause()
end

local function parseEvent(event)
  if event == hs.caffeinate.watcher.screensDidLock then
    hs.spotify.pause()
  end
end

function mod.init()
  function plugged()
    mod.muteSpeakers('Built-in Output')
    mod.muteSpeakers('MacBook Pro Speakers')
    local outputDevice = hs.audiodevice.defaultOutputDevice()
    outputDevice:setMuted(false)
    value = mod.volumes[device:name()] or 15
    outputDevice:setVolume(value)
  end

  function unplugged()
    mod.muteSpeakers('Built-in Output')
    mod.muteSpeakers('MacBook Pro Speakers')
    hs.spotify.pause()
    mod.setDefaultInputDevice()
  end

  hs.caffeinate.watcher.new(parseEvent):start()
  headphones_watcher.init(plugged, unplugged)
end

return mod
