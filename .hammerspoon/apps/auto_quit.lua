local logger = hs.logger.new('autoQuit', 'info')

local mod = {
  -- Seconds an app can stay unused before being quit, when it does not set its own `ttl`.
  defaultTtl = 15 * 60,
  -- { bundleId = 'string', ttl = seconds (optional), prompt = true to ask before quitting (optional) }
  apps = {
    { bundleId = 'com.apple.weather' },
    { bundleId = 'com.autodesk.fusion360', prompt = true },
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

local function findConfig(bundleId)
  return hs.fnutils.find(mod.apps, function(config)
    return config.bundleId == bundleId
  end)
end

local function withdrawPrompt(bundleId)
  if pendingPrompts[bundleId] then
    pendingPrompts[bundleId]:withdraw()
    pendingPrompts[bundleId] = nil
  end
end

local function onApplicationEvent(_, event, app)
  local bundleId = app and app:bundleID()
  if watchedEvents[event] and bundleId and findConfig(bundleId) then
    lastUsed[bundleId] = os.time()
    withdrawPrompt(bundleId)
  end
end

local function quit(app, bundleId, ttl)
  logger.f('Quitting %s, unused for %d seconds', app:name(), ttl)
  app:kill()
  lastUsed[bundleId] = nil
end

-- Using a notification since a blocking dialog would freeze Hammerspoon until answered.
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

local function quitIfUnused(config)
  local ttl = config.ttl or mod.defaultTtl
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

--- Quits the configured apps that have not been used for longer than their TTL.
function mod.check()
  hs.fnutils.each(mod.apps, quitIfUnused)
end

--- Starts tracking app usage, through `subscribe(fn)` application events, and periodically quits unused apps.
function mod.init(subscribe)
  subscribe(onApplicationEvent)
  timer = hs.timer.doEvery(checkInterval, mod.check)
  mod.check()
end

return mod
