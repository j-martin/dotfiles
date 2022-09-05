local mod = {}

hs.alert.defaultStyle['radius'] = 5
hs.alert.defaultStyle['textSize'] = 20

-- bindings { { key = 'string', fn = fn } }
function mod.create(modifiers, key, name, bindings)
  local mode = hs.hotkey.modal.new(modifiers, key)

  function mode:entered()
    hs.alert.show(name .. ' Mode', 120)
  end

  local function exit()
    mode:exit()
  end

  function mode:exited()
    hs.alert.closeAll()
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
