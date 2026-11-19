local utils = require 'apps/utils'
local jxa = require 'utils/jxa'

---@class ItermApp
---@field name string
---@field omni fun()
---@field context fun(): table<string, any>|nil
---@field workdir fun(): string|nil
local mod = {}

mod.name = 'iTerm2'

local maxCommandLength = 200

--- Opens the iTerm2 Open Quickly window.
function mod.omni()
  utils.switchToAndType(mod.name, { 'cmd' }, 'o')
end

--- Returns the current session title, directory, host and running command.
---@return table<string, any>|nil
function mod.context()
  local ok, session = jxa.run([[
    const s = Application(']] .. mod.name .. [[').currentWindow().currentSession();
    const v = (name) => s.variable({named: name}) || '';
    [v('autoName') || s.name(), v('path'), v('hostname'), v('username'), v('jobName'), v('commandLine')]
  ]])
  if not ok or type(session) ~= 'table' then
    return nil
  end
  local title, path, host, user, job, commandLine = table.unpack(session)
  local details = { user .. '@' .. host }
  if #commandLine > maxCommandLength then
    table.insert(details, '$ ' .. commandLine:sub(1, maxCommandLength) .. '…')
  elseif commandLine ~= '' then
    table.insert(details, '$ ' .. commandLine)
  elseif job ~= '' then
    table.insert(details, '$ ' .. job)
  end
  return { title = title, url = path, details = details }
end

--- Returns the working directory of the current session.
---@return string|nil
function mod.workdir()
  local ok, path =
    jxa.run("Application('" .. mod.name .. "').currentWindow().currentSession().variable({named: 'path'})")
  if not ok or type(path) ~= 'string' or path == '' then
    return nil
  end
  return path
end

return mod
