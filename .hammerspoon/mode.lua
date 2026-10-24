local cheatsheet = require 'keybinder/cheatsheet'

---@class ModeBinding
---@field key string
---@field fn function|nil
---@field name string|nil
---@field desc string|nil
---@field exitMode boolean|nil

---@class ModeModule
---@field create fun(modifiers: string[], key: string, name: string, bindings: ModeBinding[])
local mod = {}

hs.alert.defaultStyle['textSize'] = 20

-- bindings { { key = 'string', fn = fn } }
---@param modifiers string[]
---@param key string
---@param name string
---@param bindings ModeBinding[]
function mod.create(modifiers, key, name, bindings)
  local mode = hs.hotkey.modal.new(modifiers, key)

  local trigger = cheatsheet.modifiersString(modifiers) .. ' ' .. (key == 'space' and 'Space' or key:upper())
  cheatsheet.register(string.format('%s Mode (%s, then key)', name, trigger), bindings)

  local alertId = nil

  function mode:entered()
    alertId = hs.alert.show(name .. ' Mode', 120)
  end

  ---@return nil
  local function exit()
    mode:exit()
  end

  ---@return nil
  local function callAndExit(fn)
    return function()
      exit()
      fn()
    end
  end

  ---@param binding ModeBinding
  ---@return nil
  local function bindFn(binding)
    local message = binding.desc or binding.name
    local fn = function()
      if message ~= nil then
        hs.alert.show(message, 0.75)
      end
      if binding.fn then
        return binding.fn()
      end
      if binding.name then
        return hs.application.open(binding.name)()
      end
    end
    if binding.exitMode then
      mode:bind(modifiers, binding.key, callAndExit(fn))
    else
      mode:bind(modifiers, binding.key, fn)
    end
    mode:bind({}, binding.key, callAndExit(fn))
  end

  hs.fnutils.each(bindings, bindFn)
  mode:bind({}, 'escape', exit)
  mode:bind({}, 'q', exit)
end

return mod
