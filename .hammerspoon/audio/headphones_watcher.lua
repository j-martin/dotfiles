local mod = {}

local logger = hs.logger.new('headphones', 'debug')

local watchedDevices = {}

local pluggedFn = nil
local unpluggedFn = nil

local function audioDeviceWatch(dev_uid, event_name, event_scope, event_element)
  logger.df("Audiodevwatch args: %s, %s, %s, %s", dev_uid, event_name, event_scope, event_element)
  -- 'dIn ' is the default input changing, which `setDefaultInputDevice` itself triggers.
  if dev_uid == 'dev#' or dev_uid == 'dIn ' then
    return
  end
  local device = hs.audiodevice.findDeviceByUID(dev_uid)
  if device and device:jackConnected() then
    logger.d("Headphones plugged")
    mod.pluggedFn()
  else
    logger.d("Audio output changed, external speakers muted")
    mod.unpluggedFn()
  end
end

function mod.init(pluggedFn, unpluggedFn)
  mod.pluggedFn = pluggedFn
  mod.unpluggedFn = unpluggedFn
  hs.audiodevice.watcher.setCallback(audioDeviceWatch)
  hs.audiodevice.watcher.start()
end

return mod
