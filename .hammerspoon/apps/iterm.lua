local utils = require 'apps/utils'

---@class ItermApp
---@field name string
---@field omni fun()
---@field context fun(): table<string, any>|nil
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
  local ok, session = hs.osascript.javascript([[
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

return mod
