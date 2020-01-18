local mod = {}

local audiodevice = require "hs.audiodevice"
local alert = require "hs.alert"
local spotify = require "hs.spotify"
local logger = hs.logger.new('headphones', 'debug')

local watchedDevices = {}

local pluggedFn = nil
local unpluggedFn = nil

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
  local device = audiodevice.findDeviceByUID(dev_uid)
  if event_name == 'jack' then
    if device:jackConnected() then
      debounce("Headphones plugged", pluggedFn)
    else
      debounce("Headphones unplugged → External Speakers muted", unpluggedFn)
    end
  end
end

function mod.init(pluggedFn, unpluggedFn)
  mod.pluggedFn = pluggedFn
  mod.unpluggedFn = unpluggedFn
  local device = audiodevice.findOutputByName('Built-in Output')
  logger.df("Setting up watcher for audiodevice device %s (UID %s)", device:name(), device:uid())
  watchedDevices[device:uid()] = device:watcherCallback(audioDeviceWatch)
  watchedDevices[device:uid()]:watcherStart()
end

return mod
