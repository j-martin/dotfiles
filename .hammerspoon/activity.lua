local logger = hs.logger.new('activity', 'debug')

local mod = {
  path = os.getenv('HOME') .. '/.activity.json'
}

local watcher = nil

local eventTypes = {
  [hs.caffeinate.watcher.screensDidLock] = 'lock',
  [hs.caffeinate.watcher.screensDidUnlock] = 'unlock',
}

local function localTimestamp()
  local offset = os.date('%z')
  return os.date('%Y-%m-%dT%H:%M:%S') .. offset:sub(1, 3) .. ':' .. offset:sub(4, 5)
end

local function append(eventType)
  local line = hs.json.encode({type = eventType, timestamp = localTimestamp()})
  local file, err = io.open(mod.path, 'a')
  if not file then
    logger.ef('Failed to open %s for %s event: %s', mod.path, eventType, err)
    return
  end
  file:write(line, '\n')
  file:close()
end

local function handleEvent(event)
  local eventType = eventTypes[event]
  if eventType then
    logger.df('Recording %s event', eventType)
    append(eventType)
  end
end

--- Start recording screen lock and unlock events as JSON Lines to ~/.activity.json.
function mod.init()
  watcher = hs.caffeinate.watcher.new(handleEvent)
  watcher:start()
end

return mod
