local process = require 'utils/process'

---@class SiriApp
---@field path string
---@field trigger fun()
local mod = {}

mod.path = '/System/Applications/Siri.app'

--- Invokes Siri, fire and forget: Siri.app has no window to wait for or focus.
function mod.trigger()
  process.start('/usr/bin/open', { mod.path })
end

return mod
