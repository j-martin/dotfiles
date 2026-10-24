local utils = require 'apps/utils'

---@class IdeaApp
---@field name string
---@field omni fun()
local mod = {}

mod.name = 'IntelliJ IDEA CE'

--- Opens the IntelliJ IDEA class search.
function mod.omni()
  utils.switchToAndType(mod.name, { 'cmd' }, 'o', 10)
end

return mod
