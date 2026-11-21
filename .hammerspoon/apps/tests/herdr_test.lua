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
  ['findAgent picks the agent of the shown tab focused last'] = function()
    local layout = {
      spaces = {
        {
          active = true,
          tabs = { { active = true, terminals = { term('t1', 'copilot'), term('t2', 'claude-code'), term('t3') } } },
        },
      },
    }
    assert(herdr.findAgent(layout, { t1 = 2, t2 = 5, t3 = 9, t9 = 12 }).terminal == 't2')
    assert(herdr.findAgent(layout, { t2 = 1 }).terminal == 't2')
    assert(herdr.findAgent(layout, {}).terminal == 't1')
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
  ['reference to folders keeps the trailing slash'] = function()
    assert(herdr.reference('/src/app/pkg/', nil, nil, '/src/app') == '@pkg/')
    assert(herdr.reference('/src/app/', nil, nil, '/src/app') == '@./')
  end,
  ['findPane finds the terminal of the pane in any tab'] = function()
    local layout = {
      spaces = { { tabs = { { terminals = { { terminal = 't1', pane = 'p1' }, { terminal = 't2', pane = 'p2' } } } } } },
    }
    assert(herdr.findPane(layout, 'p2').terminal == 't2')
    assert(herdr.findPane(layout, 'p3') == nil)
    assert(herdr.findPane(layout, nil) == nil)
  end,
  ['findWaiting cycles through the blocked agents of every space after the focused pane'] = function()
    local layout = {
      spaces = {
        { tabs = { { terminals = { { terminal = 't1', pane = 'p1', status = 'blocked' } } } } },
        {
          tabs = {
            { terminals = { { terminal = 't2', pane = 'p2', status = 'working' } } },
            { terminals = { { terminal = 't3', pane = 'p3', status = 'blocked' } } },
          },
        },
      },
    }
    assert(herdr.findWaiting(layout, nil).terminal == 't1')
    assert(herdr.findWaiting(layout, 'p2').terminal == 't1')
    assert(herdr.findWaiting(layout, 'p1').terminal == 't3')
    assert(herdr.findWaiting(layout, 'p3').terminal == 't1')
  end,
  ['findWaiting is nil without blocked agents'] = function()
    local layout = { spaces = { { tabs = { { terminals = { { terminal = 't1', pane = 'p1', status = 'idle' } } } } } } }
    assert(herdr.findWaiting(layout, nil) == nil)
    assert(herdr.findWaiting(nil, nil) == nil)
  end,
  ['reference stays absolute outside the agent folder'] = function()
    assert(herdr.reference('/src/application/a.go', nil, nil, '/src/app') == '@/src/application/a.go')
  end,
  ['isCmdClick is only cmd without other modifiers'] = function()
    assert(herdr.isCmdClick({ cmd = true }))
    assert(not herdr.isCmdClick({}))
    assert(not herdr.isCmdClick({ cmd = true, shift = true }))
    assert(not herdr.isCmdClick({ cmd = true, alt = true }))
  end,
  ['orderAgents puts the last picked first, then the preferred, without non agents'] = function()
    ---@param address string
    ---@param agent string
    ---@param state string|nil
    ---@return HcTerminal
    local function hc(address, agent, state)
      return { address = address, agent = agent, state = state or 'live' }
    end
    local terminals =
      { hc('t1', 'copilot'), hc('t2', 'zsh'), hc('t3', 'claude'), hc('t4', 'copilot'), hc('t5', 'copilot', 'finished') }
    ---@param agents HcTerminal[]
    ---@return string
    local function addresses(agents)
      ---@type string[]
      local list = {}
      for _, agent in ipairs(agents) do
        table.insert(list, agent.address)
      end
      return table.concat(list, ',')
    end
    assert(addresses(herdr.orderAgents(terminals, 't4', 't3')) == 't4,t3,t1')
    assert(addresses(herdr.orderAgents(terminals, 't9', 't3')) == 't3,t1,t4')
    assert(addresses(herdr.orderAgents(terminals, nil, nil)) == 't1,t3,t4')
  end,
  ['rebase swaps the leading reference and keeps the typed prompt'] = function()
    assert(herdr.rebase('@a.go#L2 fix it', '@a.go#L2', '@/src/a.go#L2') == '@/src/a.go#L2 fix it')
    assert(herdr.rebase('fix @a.go', '@a.go', '@/src/a.go') == 'fix @a.go')
  end,
  ['withContext adds the title, URL, details and the quoted selection after the prompt'] = function()
    local context = { title = 'Brave — Docs', url = 'https://a.b', details = { 'Tab 2' } }
    local prompt = herdr.withContext('explain this  ', context, '\nline 1\n\nline 2\n')
    assert(prompt == 'explain this\n\nBrave — Docs\nhttps://a.b\nTab 2\n\n> line 1\n>\n> line 2', prompt)
  end,
  ['withContext skips what is empty'] = function()
    assert(herdr.withContext('', { title = 'Preview — a.pdf' }, '  ') == 'Preview — a.pdf')
    assert(herdr.withContext('why', nil, 'x') == 'why\n\n> x')
  end,
}
