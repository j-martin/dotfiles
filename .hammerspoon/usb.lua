local logger = hs.logger.new('usb', 'debug')

local audio = require "audio"
local process = require "utils/process"
local screen = require 'screen'

local mod = {}

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

function mod.officeLights(command)
  return function()
    process.start('/usr/local/bin/poetry', {'run', './office_automation.py', command})
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
  end
end

local watchedEvents = {
  {eventType = "removed", productName = "", productID = 7, vendorID = 1523, fn = audio.muteSpeakers},
  {eventType = "added", productName = "", productID = 7, vendorID = 1523, fn = mod.workSetup},
  {eventType = "removed", productID = 3140, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeLights("off")},
  {eventType = "added", productID = 3140, productName = "ZV-1", vendorID = 1356, vendorName = "Sony", fn = mod.officeLights("on")},
}

function mod.init()
  local handlers = buildHandlers(watchedEvents)
  hs.usb.watcher.new(handlers):start()
end

return mod
