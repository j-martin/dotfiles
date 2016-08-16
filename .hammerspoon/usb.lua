local watcher = require "hs.usb.watcher"
local inspect = require "hs.inspect"
local fnutils = require "hs.fnutils"
local logger = hs.logger.new('usb', 'debug')
local audio = require "audio"

local mod = {}
-- usb: {
--   eventType = "removed",
--   productID = 33107,
--   productName = "USB 10/100/1000 LAN",
--   vendorID = 3034,
--   vendorName = "Realtek"
--                          }
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
      if event.eventType == watchedEvent.eventType and event.productID == watchedEvent.productID and event.vendorID == watchedEvent.vendorID then
        logger.df("event matched %s", inspect(watchedEvent))
        watchedEvent.fn()
      end
    end
  end

  local handlers = fnutils.map(watchedEvents, buildHandler)

  return function(event)
    fnutils.each(handlers, function (handler) handler(event) end)
  end
end

local watchedEvents = {
  { eventType = "removed", productID = 129, productName = "Kinesis Keyboard Hub", vendorID = 1523, fn = audio.setVolume(-100) },
  { eventType = "added", productID = 129, productName = "Kinesis Keyboard Hub", vendorID = 1523, fn = audio.setVolume(15) },
}

function mod.init()
  local handlers = buildHandlers(watchedEvents)
  watcher.new(handlers):start()
end

return mod
