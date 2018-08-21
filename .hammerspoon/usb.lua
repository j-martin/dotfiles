local watcher = require "hs.usb.watcher"
local inspect = require "hs.inspect"
local fnutils = require "hs.fnutils"
local logger = hs.logger.new('usb', 'debug')
local audio = require "audio"
local alert = require "hs.alert"
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

local function buildHandlers(watchedEvents)
  local function buildHandler(watchedEvent)
    return function (event)
      logger.d(inspect(event))

      local isEventType = event.eventType == watchedEvent.eventType
      local isProductID = event.productID == watchedEvent.productID
      local isVendorID = event.vendorID == watchedEvent.vendorID

      if isEventType and isProductID and isVendorID then
        logger.df("event matched %s", inspect(watchedEvent))
        watchedEvent.fn()
        hs.reload()
      end
    end
  end

  local handlers = fnutils.map(watchedEvents, buildHandler)

  return function(event)
    fnutils.each(handlers, function (handler) handler(event) end)
  end
end

local watchedEvents = {
  {
    eventType = "removed",
    productName = "",
    productID = 7,
    vendorID = 1523,
    fn = audio.setVolume(-100)
  },
  {
    eventType = "added",
    productName = "",
    productID = 7,
    vendorID = 1523,
    fn = function()
      alert.show('Resetting brightness and volume for the office.')
      screen.setBrightness(0.8)()
      audio.setVolume(15)()
    end
  },
}

function mod.init()
  local handlers = buildHandlers(watchedEvents)
  watcher.new(handlers):start()
end

return mod
