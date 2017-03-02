-- Based on Pause/unpause playing music
-- Diego Zamboni <diego@zzamboni.org>

local mod = {}

local audio = require("hs.audiodevice")
local alert = require "hs.alert"
local logger = hs.logger.new('headphones', 'debug')
local devices = {}

local previousAlert = nil
local function dedupAlert(message)
  logger.d(message)
  if message ~= previousAlert then
    alert(message)
  end
  previousAlert = message
end

-- Per-device watcher to detect headphones in/out
local function audiodevwatch(dev_uid, event_name, event_scope, event_element)
  logger.df("Audiodevwatch args: %s, %s, %s, %s", dev_uid, event_name, event_scope, event_element)
  local device = audio.findDeviceByUID(dev_uid)
  if event_name == 'jack' then
    if device:jackConnected() then
      dedupAlert("Headphones plugged")
    else
      local outputDevice = audio.defaultOutputDevice()
      dedupAlert("Headphones unplugged → External Speakers muted")
      outputDevice:setVolume(0)
      outputDevice:setMuted(true)
    end
  end
end

function mod.init()
  for _, device in ipairs(audio.allOutputDevices()) do
    logger.df("Setting up watcher for audio device %s (UID %s)", device:name(), device:uid())
    devices[device:uid()] = device:watcherCallback(audiodevwatch)
    devices[device:uid()]:watcherStart()
  end
end

return mod
