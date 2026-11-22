local confirm = require 'utils/confirm'
local logger = require('utils/file_logger').new('autoQuit', 'info')

---@class AutoQuitAppConfig
---@field bundleId string
---@field ttlSeconds number|nil
---@field warnSeconds number|nil

---@alias AutoQuitAction 'none'|'warn'|'quit'

---@class AutoQuitModule
---@field defaultTtlSeconds number
---@field apps AutoQuitAppConfig[]
---@field askAgainSeconds number
---@field action fun(config: AutoQuitAppConfig, unusedSeconds: number, sinceWarnedSeconds: number|nil, untilAskAgainSeconds: number|nil): AutoQuitAction
---@field check fun()
---@field init fun(subscribe: fun(string, string, hs.application): nil)
local mod = {
  -- Seconds an app can stay unused before being quit, when it does not set its own `ttlSeconds`.
  defaultTtlSeconds = 2 * 60 * 60,
  -- Seconds before warning again when the user picks 'Ask again in an hour'.
  askAgainSeconds = 60 * 60,
  -- { bundleId = 'string', ttlSeconds = number (optional), warnSeconds = notify this long before quitting (optional) }
  apps = {
    { bundleId = 'com.apple.weather', ttlSeconds = 30 },
    { bundleId = 'com.autodesk.fusion360', warnSeconds = 60 * 60 },
    { bundleId = 'com.bambulab.bambu-studio', warnSeconds = 60 * 60 },
  },
}

local checkInterval = 60

-- Kept at module level so it is not garbage collected.
local timer = nil

-- bundleId -> epoch the app was last launched, focused or unfocused.
---@type table<string, number>
local lastUsed = {}

-- bundleId -> epoch the quit warning was sent.
---@type table<string, number>
local warnedAt = {}

-- bundleId -> epoch to warn again at, chosen in the warning.
---@type table<string, number>
local askAgainAt = {}

-- bundleIds the user chose to keep open until the app is quit.
---@type table<string, boolean>
local neverQuit = {}

---@param bundleId string
---@return AutoQuitAppConfig|nil
local function findConfig(bundleId)
  return hs.fnutils.find(mod.apps, function(config)
    return config.bundleId == bundleId
  end)
end

---@param bundleId string
local function clearWarning(bundleId)
  warnedAt[bundleId] = nil
  askAgainAt[bundleId] = nil
end

---@param bundleId string
local function resetTimer(bundleId)
  lastUsed[bundleId] = os.time()
  clearWarning(bundleId)
end

---@param bundleId string
local function forget(bundleId)
  clearWarning(bundleId)
  lastUsed[bundleId] = nil
  neverQuit[bundleId] = nil
end

---@param _ any
---@param event number
---@param app hs.application|nil
local function onApplicationEvent(_, event, app)
  local bundleId = app and app:bundleID()
  if not bundleId or not findConfig(bundleId) then
    return
  end
  local watcher = hs.application.watcher
  if event == watcher.terminated then
    forget(bundleId)
  elseif event == watcher.launched then
    forget(bundleId)
    resetTimer(bundleId)
  elseif event == watcher.activated or event == watcher.deactivated then
    resetTimer(bundleId)
  end
end

---@param app hs.application
---@param bundleId string
---@param ttl number
local function quit(app, bundleId, ttl)
  logger.event('autoQuit', {
    app = app:name(),
    bundleId = bundleId,
    ttlSeconds = ttl,
    unusedSeconds = os.time() - (lastUsed[bundleId] or os.time()),
  })
  app:kill()
  forget(bundleId)
end

---@param app hs.application
---@param bundleId string
---@param warnSeconds number
local function warn(app, bundleId, warnSeconds)
  warnedAt[bundleId] = os.time()
  askAgainAt[bundleId] = nil
  local name = app:name()
  confirm.choose(string.format('%s unused, quitting it in %d minutes', name, warnSeconds // 60), {
    { text = 'Ask again in an hour', subText = 'Keep ' .. name .. ' open for now' },
    { text = 'Never quit', subText = 'Keep ' .. name .. ' open until it is quit' },
    { text = 'Quit now' },
  }, function(index)
    if not warnedAt[bundleId] then
      return
    elseif index == 1 then
      clearWarning(bundleId)
      askAgainAt[bundleId] = os.time() + mod.askAgainSeconds
    elseif index == 2 then
      clearWarning(bundleId)
      neverQuit[bundleId] = true
    else
      for _, running in ipairs(hs.application.applicationsForBundleID(bundleId)) do
        quit(running, bundleId, 0)
      end
    end
  end)
end

--- Decide what to do with an app that has been unused for `unusedSeconds`.
--- Apps with `warnSeconds` are only quit once the warning has been out for `warnSeconds`,
--- so the warning is never shorter even if the timer did not run (e.g. while asleep).
---@param config AutoQuitAppConfig
---@param unusedSeconds number
---@param sinceWarnedSeconds number|nil seconds since the warning was sent, nil when not warned
---@param untilAskAgainSeconds number|nil seconds left before warning again, nil when not asked to
---@return AutoQuitAction
function mod.action(config, unusedSeconds, sinceWarnedSeconds, untilAskAgainSeconds)
  local ttl = config.ttlSeconds or mod.defaultTtlSeconds
  if not config.warnSeconds then
    return unusedSeconds >= ttl and 'quit' or 'none'
  end
  if sinceWarnedSeconds then
    return sinceWarnedSeconds >= config.warnSeconds and 'quit' or 'none'
  end
  if untilAskAgainSeconds then
    return untilAskAgainSeconds <= 0 and 'warn' or 'none'
  end
  return unusedSeconds >= ttl - config.warnSeconds and 'warn' or 'none'
end

---@param config AutoQuitAppConfig
local function quitIfUnused(config)
  local bundleId = config.bundleId
  local apps = hs.application.applicationsForBundleID(bundleId)
  if #apps == 0 then
    forget(bundleId)
    return
  end
  local frontmost = hs.application.frontmostApplication()
  if (frontmost and frontmost:bundleID() == bundleId) or neverQuit[bundleId] then
    resetTimer(bundleId)
    return
  end
  -- Apps already running when the config loads start their TTL now.
  lastUsed[bundleId] = lastUsed[bundleId] or os.time()
  local now = os.time()
  local action = mod.action(
    config,
    now - lastUsed[bundleId],
    warnedAt[bundleId] and now - warnedAt[bundleId],
    askAgainAt[bundleId] and askAgainAt[bundleId] - now
  )
  if action == 'warn' then
    warn(apps[1], bundleId, config.warnSeconds)
  elseif action == 'quit' then
    for _, app in ipairs(apps) do
      quit(app, bundleId, config.ttlSeconds or mod.defaultTtlSeconds)
    end
  end
end

--- Check whether any idle apps should be warned about or quit.
function mod.check()
  hs.fnutils.each(mod.apps, quitIfUnused)
end

--- Start the auto-quit watcher and subscribe to app lifecycle events.
---@param subscribe fun(fn: fun(appName: string, event: number, app: hs.application): nil)
function mod.init(subscribe)
  subscribe(onApplicationEvent)
  timer = hs.timer.doEvery(checkInterval, mod.check)
  mod.check()
end

return mod
