local logger = hs.logger.new('reload', 'debug')
local config = require 'config'
local privateConfig = require 'utils/private_config'

---@class ReloadModule
---@field init fun()
---@field reload fun()
---@field watcher hs.pathwatcher|nil
---@field privateWatcher hs.pathwatcher|nil
---@field snippetsWatcher hs.pathwatcher|nil
local mod = {}

local function reloadConfig(files)
  hs.fnutils.map(files, function(file)
    logger.df('File changed %s', file)
  end)

  local doReload = false
  for _, file in pairs(files) do
    local isLuaFile = file:sub(-4) == '.lua' and not file:find('/tests/', 1, true)
    local isSnippetAsset = file:find('/snippets/library/', 1, true) ~= nil
    if isLuaFile or isSnippetAsset then
      doReload = true
    end
  end
  if doReload then
    mod.reload()
  end
end

--- Reloads when the private config changes, watching its directory since editors often replace the file on save.
---@param files string[]
local function reloadPrivateConfig(files)
  ---@type string
  local name = privateConfig.luaPath:match('[^/]+$')
  for _, file in ipairs(files) do
    if file:match('[^/]+$') == name then
      logger.df('File changed %s', file)
      mod.reload()
      return
    end
  end
end

--- Reloads when a generated snippet file changes, ignoring hidden files such as temporary ones.
---@param files string[]
local function reloadSnippets(files)
  for _, file in ipairs(files) do
    if (file:match('[^/]+$') or ''):match('^[^.].*%.json$') then
      logger.df('File changed %s', file)
      mod.reload()
      return
    end
  end
end

--- Creates `path` and its missing parents.
---@param path string
local function mkdirs(path)
  ---@type string
  local current = ''
  for part in path:gmatch('[^/]+') do
    current = current .. '/' .. part
    if not hs.fs.attributes(current) then
      hs.fs.mkdir(current)
    end
  end
end

--- Reloads Hammerspoon when its config, the private config or a generated snippet file changes.
function mod.init()
  -- Keep a reference so the watcher isn't garbage collected
  if mod.watcher then
    mod.watcher:stop()
  end
  if mod.privateWatcher then
    mod.privateWatcher:stop()
  end
  if mod.snippetsWatcher then
    mod.snippetsWatcher:stop()
  end
  mod.watcher = hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/', reloadConfig):start()
  ---@type string
  local privateDirectory = privateConfig.luaPath:match('^(.*)/[^/]+$')
  mod.privateWatcher = hs.pathwatcher.new(privateDirectory, reloadPrivateConfig):start()
  -- Created so the first generated file is noticed.
  mkdirs(config.snippetJsonPath)
  mod.snippetsWatcher = hs.pathwatcher.new(config.snippetJsonPath, reloadSnippets):start()
end

--- Reloads the Hammerspoon config.
function mod.reload()
  hs.alert.show('Reloading ...')
  hs.reload()
end

return mod
