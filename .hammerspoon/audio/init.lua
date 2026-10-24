local headphones_watcher = require 'audio/headphones_watcher'

---@class AudioModule
---@field volumes table<string, number>
---@field manualInputUID string|nil
---@field setDefaultInputDevice fun()
---@field setDefaultOutputDevice fun()
---@field workSetup fun()
---@field muteSpeakers fun(name: string|nil)
---@field changeVolume fun(inc: number): fun()
---@field setVolume fun(value: number|string): fun()
---@field open fun()
---@field playpause fun()
---@field next fun()
---@field previous fun()
---@field current fun()
---@field pickOutputDevice fun()
---@field pickInputDevice fun()
---@field init fun()
local mod = {}

dacName = 'FiiO USB DAC-E10'
appleUSBWithDT1990Pro = 'USB-C to 3.5mm Headphone Jack Adapter'

mod.volumes = {}
mod.volumes[dacName] = 100
mod.volumes[appleUSBWithDT1990Pro] = 25

local inputDeviceCheckSeconds = 30

inputDevicePriority = {
  'RØDE VideoMic GO II',
  'Samson Q2U Microphone',
  'MacBook Pro Microphone',
}

outputDevicePriority = {
  'WH-1000XM3',
  appleUSBWithDT1990Pro,
  dacName,
}

-- UID of an input device picked manually; overrides `inputDevicePriority` while connected.
mod.manualInputUID = nil

-- Sets the default input to the first connected device of `inputDevicePriority`, alerting only when it changes.
function mod.setDefaultInputDevice()
  if mod.manualInputUID then
    if hs.audiodevice.findDeviceByUID(mod.manualInputUID) then
      return
    end
    mod.manualInputUID = nil
  end
  local current = hs.audiodevice.defaultInputDevice()
  for _, deviceName in ipairs(inputDevicePriority) do
    local device = hs.audiodevice.findInputByName(deviceName)
    if device then
      if current and current:uid() == device:uid() then
        return
      end
      if device:setDefaultInputDevice() then
        hs.alert.show('Input Device: ' .. deviceName)
        return
      end
    end
  end
end

function mod.setDefaultOutputDevice()
  for _, deviceName in ipairs(outputDevicePriority) do
    hs.alert.show(deviceName)
    local device = hs.audiodevice.findDeviceByName(deviceName)
    if hs.audiodevice.defaultOutputDevice() == device then
      hs.alert.show('x')
    elseif device then
      device:setDefaultOutputDevice()
      hs.alert.show('Output Device: ' .. deviceName)
      return
    end
  end
end

---@param kind string
---@return fun()
local function devicePicker(kind)
  local isInput = kind == 'input'
  local list = isInput and hs.audiodevice.allInputDevices or hs.audiodevice.allOutputDevices
  local default = isInput and hs.audiodevice.defaultInputDevice or hs.audiodevice.defaultOutputDevice

  return function()
    local current = default()
    local currentUID = current and current:uid()
    local choices = {}
    for _, device in ipairs(list()) do
      local isCurrent = device:uid() == currentUID
      table.insert(choices, {
        text = (isCurrent and '✓ ' or '   ') .. device:name(),
        subText = device:transportType(),
        uid = device:uid(),
        name = device:name(),
      })
    end
    table.sort(choices, function(a, b)
      return a.name:lower() < b.name:lower()
    end)

    local chooser = hs.chooser.new(function(choice)
      if not choice then
        return
      end
      local device = hs.audiodevice.findDeviceByUID(choice.uid)
      if not device then
        hs.alert.show('Device not found')
        return
      end
      local ok
      if isInput then
        ok = device:setDefaultInputDevice()
        if ok then
          mod.manualInputUID = choice.uid
        end
      else
        ok = device:setDefaultOutputDevice()
        if ok then
          device:setDefaultEffectDevice()
        end
      end
      hs.alert.show((ok and '' or 'Failed: ') .. (isInput and 'Input' or 'Output') .. ' Device: ' .. device:name())
    end)
    chooser:placeholderText(isInput and 'Audio input device' or 'Audio output device')
    chooser:choices(choices)
    chooser:show()
  end
end

mod.pickOutputDevice = devicePicker('output')
mod.pickInputDevice = devicePicker('input')

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

---@param fn function
---@return function
local function callAndDisplay(fn)
  return function()
    fn()
    hs.itunes.displayCurrentTrack()
  end
end

mod.next = callAndDisplay(hs.itunes.next)
mod.previous = callAndDisplay(hs.itunes.previous)
mod.current = hs.itunes.displayCurrentTrack

function mod.playpause()
  hs.alert.show('Play/Pause')
  hs.itunes.playpause()
end

---@param event number
local function parseEvent(event)
  if event == hs.caffeinate.watcher.screensDidLock then
    hs.itunes.pause()
  end
end

function mod.init()
  function plugged()
    mod.muteSpeakers('Built-in Output')
    mod.muteSpeakers('MacBook Pro Speakers')
    local outputDevice = hs.audiodevice.defaultOutputDevice()
    outputDevice:setMuted(false)
    value = mod.volumes[outputDevice:name()] or 15
    outputDevice:setVolume(value)
  end

  function unplugged()
    mod.muteSpeakers('Built-in Output')
    mod.muteSpeakers('MacBook Pro Speakers')
    hs.itunes.pause()
    mod.setDefaultInputDevice()
  end

  hs.caffeinate.watcher.new(parseEvent):start()
  headphones_watcher.init(plugged, unplugged)
  mod.setDefaultInputDevice()
  mod.inputDeviceTimer = hs.timer.doEvery(inputDeviceCheckSeconds, mod.setDefaultInputDevice)
end

return mod
