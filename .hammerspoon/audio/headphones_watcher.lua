-- Based on Pause/unpause playing music
-- Diego Zamboni <diego@zzamboni.org>

local mod = {}

local audiodev = require "hs.audiodevice"
local alert = require "hs.alert"
local misc = require '../misc'
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

-- Per-device watcher to detect headphones in/out
local function audiodevwatch(dev_uid, event_name, event_scope, event_element)
  logger.df("Audiodevwatch args: %s, %s, %s, %s", dev_uid, event_name, event_scope, event_element)
  local device = audiodev.findDeviceByUID(dev_uid)
  if event_name == 'jack' then
    if device:jackConnected() then
      debounce("Headphones plugged")
    else
      debounce("Headphones unplugged → External Speakers muted", misc.unplugLaptop)
    end
  end
end

function mod.init()
  for _, device in ipairs(audiodev.allOutputDevices()) do
    logger.df("Setting up watcher for audiodev device %s (UID %s)", device:name(), device:uid())
    devices[device:uid()] = device:watcherCallback(audiodevwatch)
    devices[device:uid()]:watcherStart()
  end
end

return mod
