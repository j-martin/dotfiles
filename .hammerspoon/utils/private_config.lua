-- Settings kept out of this public repository, in ~/.private/hammerspoon.json.
local logger = require('utils/file_logger').new('privateConfig', 'info')

local mod = {
  path = os.getenv('HOME') .. '/.private/hammerspoon.json',
}

-- Written to `mod.path` when it does not exist yet.
local defaults = {
  -- Phone number or email
  iMessageRecipient = '',
  -- Slack domain (with or without '.slack.com') -> team ID
  slackTeamMapping = { afakecompany = 'T00000000' },
}

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
function mod.get(key)
  local value = mod.read()[key]
  if value == '' then
    return nil
  end
  return value
end

return mod
