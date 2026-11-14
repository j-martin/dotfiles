-- Generates snippet groups with ~/.bin/hammerspoon-snippets-generator: the members of the work GitHub organization,
-- `githubOrg` in `snippetsGenerator` of the private config, and when gcloud is installed, the GCP organizations it
-- can see with a file of projects per organization.
-- Hammerspoon reloads when the files change, see `reload/init.lua`.
local config = require 'config'
local logger = require('utils/file_logger').new('snippetsGenerator', 'info')
local privateConfig = require 'utils/private_config'
local process = require 'utils/process'

---@class SnippetsGeneratorModule
---@field command string
---@field interval number
---@field ttl number
---@field timer hs.timer|nil
---@field task hs.task|nil
---@field sync fun()
---@field init fun()
local mod = {}

-- Installed in ~/bin with `task install`.
mod.command = process.which('hammerspoon-snippets-generator')

-- Seconds between syncs.
mod.interval = 12 * 60 * 60

-- Seconds before a sync is terminated, walking the GCP folders can be slow.
mod.ttl = 10 * 60

---@class SnippetsGeneratorConfig
---@field githubOrg string|nil

---@class SnippetsGeneratorPlan
---@field args string[] Arguments of the command.
---@field files string[] Files written in `config.snippetJsonPath`.

--- Returns the command arguments and output files for the sources set in the private config, nil when none is.
---@return SnippetsGeneratorPlan|nil
local function plan()
  ---@type string[]
  local args = { '-output-dir', config.snippetJsonPath }
  ---@type string[]
  local files = {}
  ---@type SnippetsGeneratorConfig
  local sources = privateConfig.get('snippetsGenerator') or {}
  local githubOrg = sources.githubOrg
  if githubOrg and githubOrg ~= '' then
    table.insert(args, '-github-org')
    table.insert(args, githubOrg)
    table.insert(files, 'coworkers-github.json')
    table.insert(files, 'coworkers-email.json')
  end
  -- `process.which` returns the bare name when gcloud is not installed.
  if process.which('gcloud'):find('/', 1, true) then
    table.insert(args, '-gcp')
    -- The project files are named after the organizations, unknown before the first run.
    table.insert(files, 'gcp-organizations.json')
  end
  if #files == 0 then
    return nil
  end
  return { args = args, files = files }
end

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

--- Regenerates the snippets in the background, unless the previous run is still going.
function mod.sync()
  local current = plan()
  if not current then
    logger.w('Neither githubOrg in snippetsGenerator of the private config nor gcloud is set up, skipping')
    return
  end
  if mod.task and mod.task:isRunning() then
    logger.w('Previous sync still running, skipping')
    return
  end
  mod.task = process.start(mod.command, current.args, nil, mod.ttl, { callback = onExit })
end

--- Returns whether a file of the configured sources does not exist.
---@return boolean
local function isMissingOutput()
  local current = plan()
  for _, file in ipairs(current and current.files or {}) do
    if not hs.fs.attributes(config.snippetJsonPath .. '/' .. file) then
      return true
    end
  end
  return false
end

--- Syncs every `mod.interval` seconds, and now when a snippet file was never generated.
function mod.init()
  mod.timer = hs.timer.doEvery(mod.interval, mod.sync)
  if isMissingOutput() then
    mod.sync()
  end
end

return mod
