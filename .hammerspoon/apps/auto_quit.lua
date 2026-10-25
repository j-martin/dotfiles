local logger = require('utils/file_logger').new('autoQuit', 'info')

---@class AutoQuitAppConfig
---@field bundleId string
---@field ttlSeconds number|nil
---@field prompt boolean|nil

---@class AutoQuitModule
---@field defaultTtlSeconds number
---@field apps AutoQuitAppConfig[]
---@field check fun()
---@field init fun(subscribe: fun(string, string, hs.application): nil)
local mod = {
  -- Seconds an app can stay unused before being quit, when it does not set its own `ttlSeconds`.
  defaultTtlSeconds = 2 * 60 * 60,
  -- { bundleId = 'string', ttlSeconds = number (optional), prompt = true to ask before quitting (optional) }
  apps = {
    { bundleId = 'com.apple.weather', ttlSeconds = 30 },
    { bundleId = 'com.autodesk.fusion360', prompt = true },
    { bundleId = 'com.bambulab.bambu-studio', ttlSeconds = 30 * 60, prompt = false },
  },
}

local checkInterval = 60

-- Kept at module level so it is not garbage collected.
local timer = nil

-- bundleId -> epoch the app was last launched, focused or unfocused.
local lastUsed = {}

-- bundleId -> notification waiting for the user to answer.
local pendingPrompts = {}

local watchedEvents = {
  [hs.application.watcher.launched] = true,
  [hs.application.watcher.activated] = true,
  [hs.application.watcher.deactivated] = true,
}

---@param bundleId string
---@return AutoQuitAppConfig|nil
local function findConfig(bundleId)
  return hs.fnutils.find(mod.apps, function(config)
    return config.bundleId == bundleId
  end)
end

---@param bundleId string
local function withdrawPrompt(bundleId)
  if pendingPrompts[bundleId] then
    pendingPrompts[bundleId]:withdraw()
    pendingPrompts[bundleId] = nil
  end
end

---@param _ any
---@param event number
---@param app hs.application|nil
local function onApplicationEvent(_, event, app)
  local bundleId = app and app:bundleID()
  if watchedEvents[event] and bundleId and findConfig(bundleId) then
    lastUsed[bundleId] = os.time()
    withdrawPrompt(bundleId)
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
  lastUsed[bundleId] = nil
end

-- Using a notification since a blocking dialog would freeze Hammerspoon until answered.
---@param app hs.application
---@param bundleId string
---@param ttl number
local function prompt(app, bundleId, ttl)
  if pendingPrompts[bundleId] then
    return
  end
  local notification = hs.notify.new(function(notification)
    pendingPrompts[bundleId] = nil
    if notification:activationType() == hs.notify.activationTypes.actionButtonClicked then
      quit(app, bundleId, ttl)
    else
      lastUsed[bundleId] = os.time()
    end
  end, {
    title = 'Quit ' .. app:name() .. '?',
    informativeText = string.format('Unused for %d minutes', ttl // 60),
    hasActionButton = true,
    actionButtonTitle = 'Quit',
    otherButtonTitle = 'Keep',
    withdrawAfter = 0,
  })
  pendingPrompts[bundleId] = notification:send()
end

---@param config AutoQuitAppConfig
local function quitIfUnused(config)
  local ttl = config.ttlSeconds or mod.defaultTtlSeconds
  local frontmost = hs.application.frontmostApplication()
  for _, app in ipairs(hs.application.applicationsForBundleID(config.bundleId)) do
    if frontmost and frontmost:bundleID() == config.bundleId then
      lastUsed[config.bundleId] = os.time()
    else
      -- Apps already running when the config loads start their TTL now.
      lastUsed[config.bundleId] = lastUsed[config.bundleId] or os.time()
      if os.time() - lastUsed[config.bundleId] >= ttl then
        if config.prompt then
          prompt(app, config.bundleId, ttl)
        else
          quit(app, config.bundleId, ttl)
        end
      end
    end
  end
end

--- Check whether any idle apps should be quit and prompt as needed.
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
