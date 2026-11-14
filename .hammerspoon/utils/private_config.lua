-- Settings kept out of this public repository, in ~/.private/hammerspoon.lua, a file returning a table,
-- created with the defaults on first read.
local logger = require('utils/file_logger').new('privateConfig', 'info')

---@class PrivateConfigModule
---@field luaPath string
local mod = {
  luaPath = os.getenv('HOME') .. '/.private/hammerspoon.lua',
}

-- Written to `mod.luaPath` when it does not exist yet.
---@type string
local defaultsSource = [[
-- Hammerspoon settings kept out of the public repository, see ~/.hammerspoon/utils/private_config.lua.
return {
  -- Phone number or email
  iMessageRecipient = '',
  -- Slack domain (with or without '.slack.com') -> team ID
  slackTeamMapping = { afakecompany = 'T00000000' },
  -- Added to the snippets in snippets/library, either a list, e.g. { { trigger = 'addr', text = '...', desc = 'Address' } },
  -- or a group with its own prefix and suffix, e.g. { prefix = '', suffix = '  ', snippets = { ... } }
  snippets = {},
  -- Sources of the generated snippets, see snippets/generator.lua
  snippetsGenerator = {
    -- GitHub organization whose members become snippets
    githubOrg = '',
  },
  -- Wi-Fi networks matched by SSID and address, see wifi.lua, `tailscale` being whether Tailscale is up on them,
  -- e.g. { { ssid = 'Office', cidrs = { '192.168.1.0/24' }, tailscale = false } }
  networks = {},
}
]]

--- Creates `mod.luaPath` with the defaults.
local function create()
  local directory = mod.luaPath:match('^(.*)/[^/]+$')
  if not hs.fs.attributes(directory) then
    hs.fs.mkdir(directory)
  end
  local file, openError = io.open(mod.luaPath, 'w')
  if not file then
    logger.ef('Failed to create %s: %s', mod.luaPath, openError)
    return
  end
  file:write(defaultsSource)
  file:close()
  logger.f('Created %s with the default settings', mod.luaPath)
end

--- Returns the path of the private config.
---@return string
function mod.path()
  return mod.luaPath
end

--- Returns the whole private config, creating it with the defaults when it does not exist.
---@return table<string, any>
function mod.read()
  if not hs.fs.attributes(mod.luaPath) then
    create()
  end
  local ok, config = pcall(dofile, mod.luaPath)
  if not ok or type(config) ~= 'table' then
    logger.ef('Failed to read %s: %s', mod.luaPath, config)
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
