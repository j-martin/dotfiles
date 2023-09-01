local logger = hs.logger.new('usb', 'debug')

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



function mod.workSetup()
  audio.workSetup()

  -- Keep at the bottom, because it's slow.
  hs.alert.show('Resetting brightness and volume for the office.')
  screen.setBrightness(0.8)()
end

function mod.officeAutomation(command, host)
  if not host then
    host = mod.switchLights
  end
  return function()
    process.start('/opt/homebrew/bin/poetry', {'run', './office_automation.py', '--host', host, command })
  end
end

function mod.switchToggler(host)
  return function()
    mod.officeAutomation('toggle', host)()
  end

end

local function buildHandlers(watchedEvents)
  local function buildHandler(watchedEvent)
    return function(event)
      logger.d(hs.inspect(event))

      local isEventType = event.eventType == watchedEvent.eventType
      local isProductID = event.productID == watchedEvent.productID
      local isVendorID = event.vendorID == watchedEvent.vendorID

      if isEventType and isProductID and isVendorID then
        logger.df("event matched %s", hs.inspect(watchedEvent))
        watchedEvent.fn()
      end
    end
  end

  local handlers = hs.fnutils.map(watchedEvents, buildHandler)

  return function(event)
    hs.fnutils.each(handlers, function(handler)
      handler(event)
    end)
    globalHandler:stop()
    globalHandler:start()
  end
end

local watchedEvents = {
  {eventType = "removed", productName = "", productID = 7, vendorID = 1523, fn = audio.muteSpeakers},
  {eventType = "added", productName = "", productID = 7, vendorID = 1523, fn = mod.workSetup},
  {eventType = "removed", productID = 3140, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeAutomation("off")},
  {eventType = "added", productID = 3140, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeAutomation("on")},
  {eventType = "removed", productID = 3556, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeAutomation("off")},
  {eventType = "added", productID = 3556, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeAutomation("on")},
}

function mod.init()
  local handlers = buildHandlers(watchedEvents)
  globalHandler = hs.usb.watcher.new(handlers)
  globalHandler:start()
end

return mod
