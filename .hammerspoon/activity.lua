local fileLogger = require 'utils/file_logger'
local logger = fileLogger.new('activity', 'debug')

---@class ActivityModule
---@field init fun()
local mod = {}

local watcher = nil

local eventTypes = {
  [hs.caffeinate.watcher.screensDidLock] = 'lock',
  [hs.caffeinate.watcher.screensDidUnlock] = 'unlock',
  [hs.caffeinate.watcher.systemWillSleep] = 'sleep',
  [hs.caffeinate.watcher.systemWillPowerOff] = 'shutdown',
}

---@param event number
local function handleEvent(event)
  local eventType = eventTypes[event]
  if eventType then
    logger.event(eventType)
  end
end

--- Start recording screen lock, unlock, sleep and shutdown events to the activity log.
function mod.init()
  watcher = hs.caffeinate.watcher.new(handleEvent)
  watcher:start()
end

return mod
