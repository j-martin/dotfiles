---@class HeadphonesWatcherModule
---@field pluggedFn fun()|nil
---@field unpluggedFn fun()|nil
---@field init fun(pluggedFn: fun(), unpluggedFn: fun())
local mod = {}

local logger = hs.logger.new('headphones', 'debug')

local watchedDevices = {}

---@param dev_uid string
---@param event_name string
---@param event_scope string
---@param event_element any
local function audioDeviceWatch(dev_uid, event_name, event_scope, event_element)
  logger.df('Audiodevwatch args: %s, %s, %s, %s', dev_uid, event_name, event_scope, event_element)
  if dev_uid == 'dev#' or dev_uid == 'dIn ' then
    return
  end
  local device = hs.audiodevice.findDeviceByUID(dev_uid)
  if device and device:jackConnected() then
    logger.d('Headphones plugged')
    mod.pluggedFn()
  else
    logger.d('Audio output changed, external speakers muted')
    mod.unpluggedFn()
  end
end

---@param pluggedFn fun()
---@param unpluggedFn fun()
function mod.init(pluggedFn, unpluggedFn)
  mod.pluggedFn = pluggedFn
  mod.unpluggedFn = unpluggedFn
  hs.audiodevice.watcher.setCallback(audioDeviceWatch)
  hs.audiodevice.watcher.start()
end

return mod
