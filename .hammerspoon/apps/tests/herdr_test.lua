rawset(_G, 'hs', rawget(_G, 'hs') or { logger = { new = function() end } })
local herdr = require 'apps/herdr'

---@param app string|nil
---@param terminal string
---@return HerdrTerminal
local function term(terminal, app)
  return { terminal = terminal, app = app }
end

return {
  ['findAgent picks the first claude or copilot of the shown tab'] = function()
    local layout = {
      spaces = {
        { active = false, tabs = { { active = true, terminals = { term('t1', 'claude-code') } } } },
        {
          active = true,
          tabs = {
            { active = false, terminals = { term('t2', 'claude-code') } },
            { active = true, terminals = { term('t3'), term('t4', 'copilot'), term('t5', 'claude-code') } },
          },
        },
      },
    }
    assert(herdr.findAgent(layout).terminal == 't4')
  end,
  ['findAgent is nil without an agent in the shown tab'] = function()
    local layout = { spaces = { { active = true, tabs = { { active = true, terminals = { term('t1', 'zsh') } } } } } }
    assert(herdr.findAgent(layout) == nil)
    assert(herdr.findAgent(nil) == nil)
  end,
  ['reference is relative to the agent folder, the line as #L'] = function()
    local reference = herdr.reference('/src/app/pkg/a.go', 12, 12, '/src/app')
    assert(reference == '@pkg/a.go#L12', reference)
  end,
  ['reference has the selected line range'] = function()
    local reference = herdr.reference('/src/app/a.go', 12, 20, nil)
    assert(reference == '@/src/app/a.go#L12-20', reference)
  end,
  ['reference stays absolute outside the agent folder'] = function()
    assert(herdr.reference('/src/application/a.go', nil, nil, '/src/app') == '@/src/application/a.go')
  end,
}
