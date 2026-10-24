local logger = hs.logger.new('usb', 'debug')

local appsUtils = require 'apps/utils'
local audio = require 'audio'
local kinesis = require 'kinesis'
local process = require 'utils/process'
local screen = require 'screen'

---@class UsbAutomationEvent
---@field eventType string
---@field productID number
---@field productName string
---@field vendorID number
---@field vendorName string
---@field fn function|nil
---@field lastExecuted number|nil

---@class UsbModule
---@field switchLights string
---@field switchDesk string
---@field officeAutomation fun(scene: string, command: string): fun()
---@field switchToggler fun(entityId: string): fun()
---@field init fun()
local mod = {
  switchLights = 'switch.desk_lights',
  switchDesk = 'switch.office_desk',
}

-- Kept at module level so it is not garbage collected.
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

---@param scene string
---@param command string
---@return function
function mod.officeAutomation(scene, command)
  return function()
    if scene == 'office_call' then
      if command == 'on' then
        hs.itunes.pause()
      else
        audio.setVolume('default')()
      end
    end
    process.start(appsUtils.getExecPath('office-automation'), { '--scene', scene, command }, nil, 10)
    if scene == 'desk' and command == 'off' then
      hs.itunes.pause()
      hs.caffeinate.systemSleep()
    end
  end
end

---@param entityId string
---@return function
function mod.switchToggler(entityId)
  return mod.officeAutomation('toggle', entityId)
end

---@param watchedEvents UsbAutomationEvent[]
local function buildGlobalHandler(watchedEvents)
  local function buildHandler(watchedEvent)
    return function(event)
      local isEventType = event.eventType == watchedEvent.eventType
      local isProductID = event.productID == watchedEvent.productID
      local isVendorID = event.vendorID == watchedEvent.vendorID

      local currentEpoch = process.getEpoch()
      local hasBeenDebounced = (watchedEvent.lastExecuted or 0) + 2 < currentEpoch

      if isEventType and isProductID and isVendorID and hasBeenDebounced then
        logger.df('event matched %s', hs.inspect(watchedEvent))
        watchedEvent.lastExecuted = currentEpoch
        watchedEvent.fn()
      end
    end
  end

  local handlers = hs.fnutils.map(watchedEvents, buildHandler)

  return function(event)
    logger.d(hs.inspect(event))
    local hasProductName = event.productName ~= nil and event.productName ~= ''
    if event.eventType == 'added' and hasProductName then
      hs.alert.show('USB connected: ' .. event.productName)
    end
    hs.fnutils.each(handlers, function(handler)
      handler(event)
    end)
  end
end

local watchedEvents = {
  {
    eventType = 'added',
    productID = 3556,
    productName = 'ZV-1',
    vendorID = 1356,
    vendorName = 'Sony',
    fn = mod.officeAutomation('office_call', 'on'),
  },
  {
    eventType = 'removed',
    productID = 3556,
    productName = 'ZV-1',
    vendorID = 1356,
    vendorName = 'Sony',
    fn = mod.officeAutomation('office_call', 'off'),
  },
  {
    eventType = 'added',
    productID = kinesis.productID,
    productName = 'Kinesis Keyboard Hub',
    vendorID = kinesis.vendorID,
    vendorName = 'PI Engineering',
    fn = kinesis.onConnected,
  },
  {
    eventType = 'removed',
    productID = kinesis.productID,
    productName = 'Kinesis Keyboard Hub',
    vendorID = kinesis.vendorID,
    vendorName = 'PI Engineering',
    fn = kinesis.refreshLater,
  },
}

function mod.init()
  local handlers = buildGlobalHandler(watchedEvents)
  globalHandler = hs.usb.watcher.new(handlers)
  globalHandler:start()
  kinesis.init()
end

return mod
