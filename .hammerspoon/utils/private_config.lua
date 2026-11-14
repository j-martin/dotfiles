-- Settings kept out of this public repository, in ~/.private/hammerspoon.lua when present, a file returning a table,
-- otherwise in ~/.private/hammerspoon.json.
local logger = require('utils/file_logger').new('privateConfig', 'info')

---@class PrivateConfigModule
---@field luaPath string
---@field jsonPath string
local mod = {
  luaPath = os.getenv('HOME') .. '/.private/hammerspoon.lua',
  jsonPath = os.getenv('HOME') .. '/.private/hammerspoon.json',
}

-- Written to `mod.jsonPath` when neither file exists yet.
local defaults = {
  -- Phone number or email
  iMessageRecipient = '',
  -- Slack domain (with or without '.slack.com') -> team ID
  slackTeamMapping = { afakecompany = 'T00000000' },
  -- Added to the snippets in snippets/library, either a list, e.g. [{ "trigger": "addr", "text": "...", "desc": "Address" }],
  -- or a group with its own prefix and suffix, e.g. { "prefix": "", "suffix": "  ", "snippets": [...] }
  snippets = {},
}

---@return nil
local function create()
  local directory = mod.jsonPath:match('^(.*)/[^/]+$')
  if not hs.fs.attributes(directory) then
    hs.fs.mkdir(directory)
  end
  if not hs.json.write(defaults, mod.jsonPath, true, false) then
    logger.ef('Failed to create %s', mod.jsonPath)
    return
  end
  logger.f('Created %s with the default settings', mod.jsonPath)
end

--- Returns the path of the private config in use, the Lua file when present.
---@return string
function mod.path()
  if hs.fs.attributes(mod.luaPath) then
    return mod.luaPath
  end
  return mod.jsonPath
end

--- Returns the whole private config, creating the JSON file with the defaults when neither file exists.
---@return table<string, any>
function mod.read()
  if hs.fs.attributes(mod.luaPath) then
    local ok, config = pcall(dofile, mod.luaPath)
    if not ok or type(config) ~= 'table' then
      logger.ef('Failed to read %s: %s', mod.luaPath, config)
      return {}
    end
    return config
  end
  if not hs.fs.attributes(mod.jsonPath) then
    create()
  end
  local config = hs.json.read(mod.jsonPath)
  if not config then
    logger.ef('Failed to read %s', mod.jsonPath)
    return {}
  end
  return config
end

--- Returns the value of `key`, or nil when it is unset or empty.
---@param key string
---@return any
function mod.get(key)
  local value = mod.read()[key]
  if value == '' then
    return nil
  end
  return value
end

return mod
