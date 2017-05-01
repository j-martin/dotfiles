local hotkey = require 'hs.hotkey'
local alert = require('hs.alert')
local fnutils = require "hs.fnutils"

local mod = {}

-- bindings { { key = 'string', fn = fn } }
function mod.create(modifiers, key, name, bindings)
  local mode = hotkey.modal.new(modifiers, key)

  function mode:entered()
    alert.show(name .. ' Mode', 120)
  end

  local function exit()
    mode:exit()
  end

  function mode:exited()
    alert.closeAll()
  end

  local function callAndExit(fn)
    return function()
      fn()
      exit()
    end
  end

  local function bindFn(binding)
    mode:bind({}, binding.key, binding.fn)
    mode:bind(modifiers, binding.key, callAndExit(binding.fn))
  end

  fnutils.each(bindings, bindFn)
  mode:bind({}, 'escape', exit)
end

return mod
