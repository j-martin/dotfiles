local logger = hs.logger.new('usb', 'debug')

local apps = require "apps"
local audio = require "audio"
local process = require "utils/process"
local screen = require 'screen'

local mod = {
  switchLights = 'lights.office.jmartin.ca',
  switchDesk = 'desk.office.jmartin.ca'
}

-- Global USB handler to workaround.
-- There seems to be a bug where the USB handler will stop responding after the first invocation.
local globalHandler = nil

-- Event Example
-- usb: {
--   eventType = "removed",
--   productID = 33107,
--   productName = "USB 10/100/1000 LAN",
--   vendorID = 3034,
--   vendorName = "Realtek"
-- }
-- usb: {
--   eventType = "added",
--   productID = 33107,
--   productName = "USB 10/100/1000 LAN",
--   vendorID = 3034,
--   vendorName = "Realtek"
-- }
-- usb: {
--   eventType = "added",
--   productID = 3140,
--   productName = "ZV-1",
--   vendorID = 1356,
--   vendorName = "Sony"
-- }

function mod.officeAutomation(command, host)
  if not host then
    host = mod.switchLights
  end
  return function()
    process.start(apps.getExecPath('poetry'), {'run', './office_automation.py', '--host', host, command }, nil, 10)
  end
end

function mod.switchToggler(host)
  return mod.officeAutomation('toggle', host)
end

local function buildGlobalHandler(watchedEvents)
  local function buildHandler(watchedEvent)
    return function(event)
      local isEventType = event.eventType == watchedEvent.eventType
      local isProductID = event.productID == watchedEvent.productID
      local isVendorID = event.vendorID == watchedEvent.vendorID

      -- Trying to prevent too many executions
      local currentEpoch = process.getEpoch()
      local hasBeenDebounced = (watchedEvent.lastExecuted or 0) + 2 < currentEpoch

      if isEventType and isProductID and isVendorID and hasBeenDebounced then
        logger.df("event matched %s", hs.inspect(watchedEvent))
        watchedEvent.lastExecuted = currentEpoch
        watchedEvent.fn()
      end
    end
  end

  local handlers = hs.fnutils.map(watchedEvents, buildHandler)

  local lastExecuted = 0

  return function(event)
    logger.d(hs.inspect(event))
    hs.fnutils.each(handlers, function(handler) handler(event) end)

    -- Trying to prevent too many executions
    local currentEpoch = process.getEpoch()
    -- Workaround the watcher hanging after a few execution.
    if lastExecuted + 2 <  currentEpoch then
      logger.d('Restarting USB event handler...')
      globalHandler:stop():start()
      lastExecuted = currentEpoch
    end
  end
end

local watchedEvents = {
  -- Network adapter on office Thunderbolt dock
  {eventType = "added", productID = 33107, productName = "USB 10/100/1000 LAN", vendorID = 3034, vendorName = "Realtek", fn = mod.officeAutomation("off", mod.switchDesk)},

  -- ZV-1 with in USB mass storage mode
  -- {eventType = "added", productID = 3140, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeAutomation("on")},
  -- {eventType = "removed", productID = 3140, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeAutomation("off")},

  -- ZV-1 with webcam in USB streaming mod
  {eventType = "added", productID = 3556, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeAutomation("on")},
  {eventType = "removed", productID = 3556, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeAutomation("off")},
}

function mod.init()
  local handlers = buildGlobalHandler(watchedEvents)
  globalHandler = hs.usb.watcher.new(handlers)
  globalHandler:start()
end

return mod
