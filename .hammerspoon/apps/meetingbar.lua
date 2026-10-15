-- Restart MeetingBar on wake to work around its Google Calendar refresh hanging
-- when the system wakes before the network is up.
-- https://github.com/leits/MeetingBar/pull/974
local logger = hs.logger.new('meetingbar', 'info')

local mod = {}

local bundleID = 'leits.MeetingBar'
local probeHost = 'www.googleapis.com'
local networkTimeoutSeconds = 300
local pollIntervalSeconds = 5

local sleepWatcher = nil
local pendingTimer = nil

local function isNetworkReachable()
  local status = hs.network.reachability.forHostName(probeHost):status()
  return (status & hs.network.reachability.flags.reachable) > 0
end

-- Quit MeetingBar if running, then launch it again.
function mod.restart()
  local app = hs.application.get(bundleID)
  if not app then
    logger.i('MeetingBar is not running, skipping restart')
    return
  end

  logger.i('Restarting MeetingBar')
  app:kill()
  hs.timer.waitWhile(
    function() return hs.application.get(bundleID) ~= nil end,
    function() hs.application.open(bundleID) end,
    0.5
  )
end

local function restartWhenOnline()
  if pendingTimer then
    pendingTimer:stop()
  end

  local startedAt = os.time()
  pendingTimer = hs.timer.waitUntil(
    function()
      return isNetworkReachable() or os.time() - startedAt > networkTimeoutSeconds
    end,
    function()
      pendingTimer = nil
      if not isNetworkReachable() then
        logger.w('Network still unreachable after wake, restarting MeetingBar anyway')
      end
      mod.restart()
    end,
    pollIntervalSeconds
  )
end

local function handleSleepEvent(event)
  if event == hs.caffeinate.watcher.systemDidWake then
    restartWhenOnline()
  end
end

-- Start watching for system wake events.
function mod.init()
  sleepWatcher = hs.caffeinate.watcher.new(handleSleepEvent)
  sleepWatcher:start()
end

return mod
