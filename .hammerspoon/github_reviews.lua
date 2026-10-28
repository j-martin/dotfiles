-- Syncs the GitHub pull requests awaiting my review to Reminders with ~/.bin/github-review-reminders.
local logger = require('utils/file_logger').new('githubReviews', 'info')
local appsUtils = require 'apps/utils'
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

local HOME = os.getenv('HOME')

-- Installed in ~/bin with `task install`.
mod.command = appsUtils.getExecPath('github-review-reminders')

-- Seconds between syncs.
mod.interval = 5 * 60

-- Seconds before a sync is terminated.
mod.ttl = 2 * 60

-- `gh` is installed with mise.
-- RIC_IGNORED_REPOSITORIES is added from the login shell by `mod.init`.
---@type table<string, string>
local env = {
  PATH = HOME .. '/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin',
}

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
  local ignored = hs.execute('printf %s "$RIC_IGNORED_REPOSITORIES"', true)
  env.RIC_IGNORED_REPOSITORIES = ignored or ''
  mod.timer = hs.timer.doEvery(mod.interval, mod.sync)
  mod.sync()
end

return mod
