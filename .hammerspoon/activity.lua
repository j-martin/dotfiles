local fileLogger = require 'utils/file_logger'
local logger = fileLogger.new('activity', 'debug')

local mod = {}

local watcher = nil

local eventTypes = {
  [hs.caffeinate.watcher.screensDidLock] = 'lock',
  [hs.caffeinate.watcher.screensDidUnlock] = 'unlock',
}

local function handleEvent(event)
  local eventType = eventTypes[event]
  if eventType then
    logger.event(eventType)
  end
end

--- Start recording screen lock and unlock events to the activity log.
function mod.init()
  watcher = hs.caffeinate.watcher.new(handleEvent)
  watcher:start()
end

return mod
