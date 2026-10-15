local utils = require 'apps/utils'

local mod = {}

mod.name = 'IntelliJ IDEA CE'

--- Opens the IntelliJ IDEA class search.
function mod.omni()
  utils.switchToAndType(mod.name, {'cmd'}, 'o', 10)
end

return mod
