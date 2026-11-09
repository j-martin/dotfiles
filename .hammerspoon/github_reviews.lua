-- Syncs the GitHub pull requests awaiting my review to Reminders with ~/.bin/github-review-reminders.
local logger = require('utils/file_logger').new('githubReviews', 'info')
local process = require 'utils/process'
local reminders = require 'apps/reminders'

---@class GithubReviewsModule
---@field command string
---@field interval number
---@field ttl number
---@field timer hs.timer|nil
---@field task hs.task|nil
---@field sync fun()
---@field init fun()
local mod = {}

-- Installed in ~/bin with `task install`.
mod.command = process.which('github-review-reminders')

-- Seconds between syncs.
mod.interval = 5 * 60

-- Seconds before a sync is terminated.
mod.ttl = 2 * 60

-- `gh` is found through the mise shims in `process.PATH`.
-- RIC_IGNORED_REPOSITORIES is added from the login shell by `mod.init`, when set.
---@type table<string, string>
local env = {}

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
function mod.sync()
  if mod.task and mod.task:isRunning() then
    logger.w('Previous sync still running, skipping')
    return
  end
  local args = {}
  if reminders.list ~= '' then
    args = { '-list', reminders.list }
  end
  mod.task = process.start(mod.command, args, nil, mod.ttl, { env = env, callback = onExit })
end

--- Syncs now and every `mod.interval` seconds.
function mod.init()
  -- The interactive shell may print escape sequences, so the value follows a marker.
  local marker = '__RIC_IGNORED_REPOSITORIES__'
  ---@type string[]
  local args = { '-l', '-i', '-c', 'printf "\\n' .. marker .. '%s\\n" "${RIC_IGNORED_REPOSITORIES:-}"' }

  ---@param exitCode number
  ---@param stdOut string|nil
  local function onShellExit(exitCode, stdOut)
    ---@type string
    local ignored = (stdOut or ''):match(marker .. '([^\n]*)') or ''
    ignored = ignored:gsub('^%s+', ''):gsub('%s+$', '')
    if ignored ~= '' then
      env.RIC_IGNORED_REPOSITORIES = ignored
    else
      env.RIC_IGNORED_REPOSITORIES = nil
      logger.f('RIC_IGNORED_REPOSITORIES is not set in the shell (exit %d), no repository is ignored', exitCode)
    end
    mod.timer = hs.timer.doEvery(mod.interval, mod.sync)
    mod.sync()
  end

  process.start(os.getenv('SHELL') or '/bin/zsh', args, nil, 30, { callback = onShellExit })
end

return mod
