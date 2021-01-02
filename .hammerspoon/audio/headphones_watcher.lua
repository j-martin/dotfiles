local mod = {}

local audiodevice = require "hs.audiodevice"
local watcher = require "hs.audiodevice.watcher"
local alert = require "hs.alert"
local spotify = require "hs.spotify"
local logger = hs.logger.new('headphones', 'debug')

local watchedDevices = {}

local pluggedFn = nil
local unpluggedFn = nil

local previousTime = 0

local function debounce(message, fn)
  logger.d(message)
  if os.time() - 1 > previousTime then
    alert(message)
    previousTime = os.time()
  end
  if fn then
    fn()
  end
end

local function audioDeviceWatch(dev_uid, event_name, event_scope, event_element)
  logger.df("Audiodevwatch args: %s, %s, %s, %s", dev_uid, event_name, event_scope, event_element)
  if dev_uid == 'dev#' then
    return
  end
  local device = audiodevice.findDeviceByUID(dev_uid)
  if device and device:jackConnected() then
    debounce("Headphones plugged", mod.pluggedFn)
  else
    debounce("Audio Output Change → External Speakers muted", mod.unpluggedFn)
  end
end

function mod.init(pluggedFn, unpluggedFn)
  mod.pluggedFn = pluggedFn
  mod.unpluggedFn = unpluggedFn
  watcher.setCallback(audioDeviceWatch)
  watcher.start()
end

return mod
