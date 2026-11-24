-- Syncs the GitHub pull requests awaiting my review to Reminders with ~/.bin/github-review-reminders,
-- installed in ~/bin with `task install`.
local logger = require('utils/file_logger').new('githubReviews', 'info')
local process = require 'utils/process'

-- `gh` is found through the mise shims in `process.PATH`.
local mod = require('reminders_sync').new({ name = 'githubReviews', command = 'github-review-reminders' })

--- Adds RIC_IGNORED_REPOSITORIES from the login shell to the environment, when set, then syncs
--- now and every `mod.interval` seconds.
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
      mod.env.RIC_IGNORED_REPOSITORIES = ignored
    else
      mod.env.RIC_IGNORED_REPOSITORIES = nil
      logger.f('RIC_IGNORED_REPOSITORIES is not set in the shell (exit %d), no repository is ignored', exitCode)
    end
    mod.start()
  end

  process.start(os.getenv('SHELL') or '/bin/zsh', args, nil, 30, { callback = onShellExit })
end

return mod
