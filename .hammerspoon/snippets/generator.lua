-- Generates snippet groups with ~/.bin/hammerspoon-snippets-generator, which discovers the GitHub organizations with
-- `gh org list` and, when gcloud is installed, the GCP organizations and billing accounts it can see.
-- Hammerspoon reloads when the files change, see `reload/init.lua`.
local config = require 'config'
local logger = require('utils/file_logger').new('snippetsGenerator', 'info')
local process = require 'utils/process'

---@class SnippetsGeneratorModule
---@field dir string
---@field interval number
---@field ttl number
---@field timer hs.timer|nil
---@field task hs.task|nil
---@field sync fun()
---@field init fun()
local mod = {}

-- The generator is run with its `generate` mise task, which rebuilds it first when its sources changed.
mod.dir = '~/.bin/hammerspoon-snippets-generator'

-- Seconds between syncs.
mod.interval = 12 * 60 * 60

-- Seconds before a sync is terminated, walking the GCP folders can be slow.
mod.ttl = 10 * 60

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
  if mod.task and mod.task:isRunning() then
    logger.w('Previous sync still running, skipping')
    return
  end
  mod.task = process.miseRun({
    task = 'generate',
    dir = mod.dir,
    args = { config.snippetJsonPath },
    ttl = mod.ttl,
    options = { callback = onExit },
  })
end

--- Returns whether the output directory has no JSON files yet.
---@return boolean
local function isMissingOutput()
  if not hs.fs.attributes(config.snippetJsonPath) then
    return true
  end
  for file in hs.fs.dir(config.snippetJsonPath) do
    if file:match('^[^.].*%.json$') then
      return false
    end
  end
  return true
end

--- Syncs every `mod.interval` seconds, and now when no snippet files are present.
function mod.init()
  mod.timer = hs.timer.doEvery(mod.interval, mod.sync)
  if isMissingOutput() then
    mod.sync()
  end
end

return mod
