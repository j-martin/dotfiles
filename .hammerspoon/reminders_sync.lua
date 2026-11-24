-- Runs a ~/bin reminders sync tool (e.g. github-review-reminders, jira-reminders) periodically
-- against `reminders.list`, logging its output.
local process = require 'utils/process'
local reminders = require 'apps/reminders'

---@class RemindersSyncOptions
---@field name string Logger name.
---@field command string Executable name, looked up with `process.which`.
---@field interval number|nil Seconds between syncs, 5 minutes by default.
---@field ttl number|nil Seconds before a sync is terminated, 2 minutes by default.

local mod = {}

--- Returns a sync of the command, started with `init`.
---@param options RemindersSyncOptions
---@return RemindersSync
function mod.new(options)
  local logger = require('utils/file_logger').new(options.name, 'info')

  ---@class RemindersSync
  ---@field timer hs.timer|nil
  ---@field task hs.task|nil
  local sync = {}
  sync.command = process.which(options.command)
  sync.interval = options.interval or (5 * 60)
  sync.ttl = options.ttl or (2 * 60)
  -- Extra environment variables of the command.
  ---@type table<string, string>
  sync.env = {}

  ---@param exitCode number
  ---@param stdOut string
  ---@param stdErr string
  local function onExit(exitCode, stdOut, stdErr)
    local output = (stdOut .. stdErr):gsub('%s+$', '')
    if exitCode ~= 0 then
      logger.ef('Sync failed (%d): %s', exitCode, output)
      return
    end
    logger.f('%s', output)
  end

  --- Runs a sync, unless the previous one is still running.
  function sync.sync()
    if sync.task and sync.task:isRunning() then
      logger.w('Previous sync still running, skipping')
      return
    end
    ---@type string[]
    local args = {}
    if reminders.list ~= '' then
      args = { '-list', reminders.list }
    end
    sync.task = process.start(sync.command, args, nil, sync.ttl, { env = sync.env, callback = onExit })
  end

  --- Syncs now and every `interval` seconds.
  function sync.start()
    sync.timer = hs.timer.doEvery(sync.interval, sync.sync)
    sync.sync()
  end

  sync.init = sync.start

  return sync
end

return mod
