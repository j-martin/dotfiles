-- Same API as hs.logger, plus every enabled message is appended as JSON Lines to ~/Library/Logs/hammerspoon/logs.jsonl.
-- Structured events, such as the lock/unlock read by ~/.bin/activity-hours, are recorded with `logger.event`.
local internal = hs.logger.new('fileLogger', 'info')

local directory = os.getenv('HOME') .. '/Library/Logs/hammerspoon'

local mod = {
  path = directory .. '/logs.jsonl',
}

local levels = { error = 1, warning = 2, info = 3, debug = 4, verbose = 5 }

-- hs.logger method -> level and whether it takes a format string
local methods = {
  e = { level = 'error' },
  ef = { level = 'error', formatted = true },
  w = { level = 'warning' },
  wf = { level = 'warning', formatted = true },
  i = { level = 'info' },
  f = { level = 'info', formatted = true },
  d = { level = 'debug' },
  df = { level = 'debug', formatted = true },
  v = { level = 'verbose' },
  vf = { level = 'verbose', formatted = true },
}

local function localTimestamp()
  local offset = os.date('%z') --[[@as string]]
  return os.date('%Y-%m-%dT%H:%M:%S') --[[@as string]] .. offset:sub(1, 3) .. ':' .. offset:sub(4, 5)
end

local function join(...)
  local parts = {}
  for i = 1, select('#', ...) do
    table.insert(parts, tostring(select(i, ...)))
  end
  return table.concat(parts, ' ')
end

local function write(entry)
  entry.timestamp = localTimestamp()
  if not hs.fs.attributes(directory) then
    hs.fs.mkdir(directory)
  end
  local file, err = io.open(mod.path, 'a')
  if not file then
    internal.ef('Failed to open %s: %s', mod.path, err)
    return
  end
  file:write(hs.json.encode(entry), '\n')
  file:close()
end

--- Creates a logger like `hs.logger.new(id, level)` that also writes its enabled messages to `mod.path`.
function mod.new(id, level)
  local console = hs.logger.new(id, level)
  local logger = {}

  for method, spec in pairs(methods) do
    logger[method] = function(...)
      console[method](...)
      if console.level >= levels[spec.level] then
        local message = spec.formatted and string.format(...) or join(...)
        write({ level = spec.level, logger = id, message = message })
      end
    end
  end

  --- Records an `eventType` event at info level, with the optional `fields` stored as top-level keys.
  function logger.event(eventType, fields)
    fields = fields or {}
    console.f('%s %s', eventType, hs.json.encode(fields))
    if console.level >= levels.info then
      local entry = { level = 'info', logger = id, type = eventType }
      for key, value in pairs(fields) do
        entry[key] = value
      end
      write(entry)
    end
  end

  return setmetatable(logger, { __index = console })
end

return mod
