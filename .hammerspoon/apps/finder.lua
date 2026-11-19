local jxa = require 'utils/jxa'

---@class FinderApp
---@field name string
---@field context fun(): table<string, string>|nil
---@field folder fun(): string|nil
local mod = {}

mod.name = 'Finder'

--- Returns the name and URL of the first selected file.
---@return table<string, string>|nil
function mod.context()
  local ok, file = jxa.run("const f = Application('" .. mod.name .. "').selection()[0]; f ? [f.name(), f.url()] : null")
  if not ok or type(file) ~= 'table' then
    return nil
  end
  return { title = file[1], url = file[2] }
end

--- Returns the folder of the front window, or the desktop without windows, with a trailing `/`.
---@return string|nil
function mod.folder()
  local ok, path = jxa.run(
    "const f = Application('"
      .. mod.name
      .. "'); const w = f.finderWindows; $.NSURL.URLWithString(w.length ? w[0].target().url() : f.desktop.url()).path.js"
  )
  if not ok or type(path) ~= 'string' or path == '' then
    return nil
  end
  return path:sub(-1) == '/' and path or path .. '/'
end

return mod
