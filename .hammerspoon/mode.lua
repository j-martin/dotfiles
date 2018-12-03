local hotkey = require 'hs.hotkey'
local alert = require('hs.alert')
local fnutils = require "hs.fnutils"
local application = require "hs.application"

local mod = {}

alert.defaultStyle['radius'] = 5
alert.defaultStyle['textSize'] = 20

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
      exit()
      fn()
    end
  end

  local function bindFn(binding)
    local message = binding.desc or binding.name
    local fn = function()
      if message ~= nil then
        alert.show(message, 0.75)
      end
      if binding.fn then
        return binding.fn()
      end
      application.open(binding.name)()
    end
    if binding.exitMode then
      mode:bind(modifiers, binding.key, callAndExit(fn))
    else
      mode:bind(modifiers, binding.key, fn)
    end
    mode:bind({}, binding.key, callAndExit(fn))
  end

  fnutils.each(bindings, bindFn)
  mode:bind({}, 'escape', exit)
  mode:bind({}, 'q', exit)
end

return mod
