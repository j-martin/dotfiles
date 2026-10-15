local logger = hs.logger.new('activity', 'debug')

local mod = {
  path = os.getenv('HOME') .. '/.activity.json'
}

local watcher = nil

local eventTypes = {
  [hs.caffeinate.watcher.screensDidLock] = 'lock',
  [hs.caffeinate.watcher.screensDidUnlock] = 'unlock',
}

local function append(eventType)
  local entries = hs.json.read(mod.path) or {}
  table.insert(entries, {type = eventType, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')})
  if not hs.json.write(entries, mod.path, true, true) then
    logger.ef('Failed to write %s event to %s', eventType, mod.path)
  end
end

local function handleEvent(event)
  local eventType = eventTypes[event]
  if eventType then
    logger.df('Recording %s event', eventType)
    append(eventType)
  end
end

--- Start recording screen lock and unlock events to ~/.activity.json.
function mod.init()
  watcher = hs.caffeinate.watcher.new(handleEvent)
  watcher:start()
end

return mod
