-- Settings kept out of this public repository, in ~/.private/hammerspoon.json.
local logger = require('utils/file_logger').new('privateConfig', 'info')

---@class PrivateConfig
---@field path string
---@field iMessageRecipient string
---@field slackTeamMapping table<string, string>
---@field read fun(): table<string, any>
---@field get fun(key: string): string|nil

---@type PrivateConfig
local mod = {
  path = os.getenv('HOME') .. '/.private/hammerspoon.json',
  iMessageRecipient = '',
  slackTeamMapping = {},
  read = function()
    return {}
  end,
  get = function(key)
    return nil
  end,
}

---@type PrivateConfig
local defaults = {
  path = mod.path,
  iMessageRecipient = '',
  slackTeamMapping = { afakecompany = 'T00000000' },
  read = mod.read,
  get = mod.get,
}

---@return nil
local function create()
  local directory = mod.path:match('^(.*)/[^/]+$')
  if not hs.fs.attributes(directory) then
    hs.fs.mkdir(directory)
  end
  if not hs.json.write(defaults, mod.path, true, false) then
    logger.ef('Failed to create %s', mod.path)
    return
  end
  logger.f('Created %s with the default settings', mod.path)
end

--- Returns the whole private config, creating the file with the defaults when missing.
---@return table<string, any>
function mod.read()
  if not hs.fs.attributes(mod.path) then
    create()
  end
  local config = hs.json.read(mod.path)
  if not config then
    logger.ef('Failed to read %s', mod.path)
    return {}
  end
  return config
end

--- Returns the value of `key`, or nil when it is unset or empty.
---@param key string
---@return string|nil
function mod.get(key)
  local value = mod.read()[key]
  if value == '' then
    return nil
  end
  return value
end

return mod
