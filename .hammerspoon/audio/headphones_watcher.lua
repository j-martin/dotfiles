local mod = {}

local audiodev = require "hs.audiodevice"
local alert = require "hs.alert"
local spotify = require "hs.spotify"
local logger = hs.logger.new('headphones', 'debug')

local devices = {}

local previousAlert

local function debounce(message, fn)
  logger.d(message)
  if message ~= previousAlert then
    alert(message)
    previousAlert = message
  end
  if fn then
    fn()
  end
end

local function audioDeviceWatch(dev_uid, event_name, event_scope, event_element)
  logger.df("Audiodevwatch args: %s, %s, %s, %s", dev_uid, event_name, event_scope, event_element)
  local device = audiodev.findDeviceByUID(dev_uid)
  if event_name == 'jack' then
    if device:jackConnected() then
      debounce("Headphones plugged", mod.plugged)
    else
      debounce("Headphones unplugged → External Speakers muted", mod.unplugged)
    end
  end
end

function mod.plugged()
  local outputDevice = audiodev.defaultOutputDevice()
  outputDevice:setMuted(false)
  outputDevice:setVolume(15)
end

function mod.unplugged()
  local outputDevice = audiodev.defaultOutputDevice()
  outputDevice:setVolume(0)
  outputDevice:setMuted(true)
  spotify.pause()
end

function mod.init()
  for _, device in ipairs(audiodev.allOutputDevices()) do
    logger.df("Setting up watcher for audiodev device %s (UID %s)", device:name(), device:uid())
    devices[device:uid()] = device:watcherCallback(audioDeviceWatch)
    devices[device:uid()]:watcherStart()
  end
end

return mod
