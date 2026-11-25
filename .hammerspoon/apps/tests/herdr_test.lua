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
  ['findUnchecked cycles through the idle agents of every space not checked since their last turn'] = function()
    local layout = {
      spaces = {
        { tabs = { { terminals = { { terminal = 't1', pane = 'p1', status = 'idle', app = 'claude-code' } } } } },
        { tabs = { { terminals = { { terminal = 't2', pane = 'p2', status = 'idle', app = 'copilot' } } } } },
        { tabs = { { terminals = { { terminal = 't3', pane = 'p3', status = 'idle', app = 'claude-code' } } } } },
        { tabs = { { terminals = { { terminal = 't4', pane = 'p4', status = 'working', app = 'copilot' } } } } },
        { tabs = { { terminals = { { terminal = 't5', pane = 'p5', status = 'idle' } } } } },
      },
    }
    local turns = { t1 = 3, t2 = 5, t3 = 1, t4 = 2 }
    local checked = { t2 = 5, t3 = 0 }
    assert(herdr.findUnchecked(layout, 'p1', turns, checked).terminal == 't3')
    assert(herdr.findUnchecked(layout, 'p3', turns, checked).terminal == 't1')
    assert(herdr.findUnchecked(layout, 'p1', turns, { t1 = 3, t2 = 5, t3 = 1 }) == nil)
  end,
  ['nextPane cycles through the panes of the shown tab only'] = function()
    local layout = {
      spaces = {
        { active = false, tabs = { { active = true, terminals = { { terminal = 't1', pane = 'p1' } } } } },
        {
          active = true,
          tabs = {
            { active = false, terminals = { { terminal = 't2', pane = 'p2' } } },
            { active = true, terminals = { { terminal = 't3', pane = 'p3' }, { terminal = 't4', pane = 'p4' } } },
          },
        },
      },
    }
    assert(herdr.nextPane(layout, 'p3').terminal == 't4')
    assert(herdr.nextPane(layout, 'p4').terminal == 't3')
    assert(herdr.nextPane(layout, 'p1').terminal == 't3')
    assert(herdr.nextPane(nil, 'p3') == nil)
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
  ['isUnder matches the folder itself and what is inside it only'] = function()
    assert(herdr.isUnder('/src/app/a.go', '/src/app/'))
    assert(herdr.isUnder('/src/app/', '/src/app'))
    assert(not herdr.isUnder('/src/app-web/a.go', '/src/app'))
    assert(not herdr.isUnder(nil, '/src/app'))
  end,
  ['repoRoot is the closest folder with a .git'] = function()
    ---@param path string
    ---@return boolean
    local function exists(path)
      return path == '/src/app/.git' or path == '/src/app/vendor/lib/.git'
    end
    assert(herdr.repoRoot('/src/app/pkg/a.go', exists) == '/src/app')
    assert(herdr.repoRoot('/src/app/vendor/lib/', exists) == '/src/app/vendor/lib')
    assert(herdr.repoRoot('/home/.zshrc', exists) == nil)
  end,
  ['relates folders inside the repo, else holding the path'] = function()
    assert(herdr.relates('/src/app/pkg', '/src/app/a.go', '/src/app'))
    assert(not herdr.relates('/src', '/src/app/a.go', '/src/app'))
    assert(herdr.relates('/home', '/home/.config/a.lua', nil))
    assert(not herdr.relates('/home/.vim', '/home/.config/a.lua', nil))
    assert(not herdr.relates(nil, '/home/a.lua', nil))
  end,
  ['findSpace prefers the shown related space, else the deepest related one'] = function()
    ---@param id string
    ---@param folder string
    ---@param shown boolean|nil
    ---@return HerdrSpace
    local function space(id, folder, shown)
      return { id = id, folder = folder, active = shown == true, tabs = {} }
    end
    local layout = { spaces = { space('s1', '/src/app'), space('s2', '/src/app/pkg'), space('s3', '/src/ops', true) } }
    assert(herdr.findSpace(layout, '/src/app/a.go', '/src/app').id == 's2')
    assert(herdr.findSpace(layout, '/src/web/a.go', '/src/web') == nil)
    assert(herdr.findSpace(layout, nil, nil).id == 's3')
    layout.spaces[1].active, layout.spaces[3].active = true, false
    assert(herdr.findSpace(layout, '/src/app/a.go', '/src/app').id == 's1')
  end,
  ['findSpace matches a space by the live folder of its terminals'] = function()
    local layout = {
      spaces = {
        {
          id = 's1',
          folder = '/home/.hammerspoon',
          active = false,
          tabs = { { active = true, terminals = { term('t1') } } },
        },
        { id = 's2', folder = '/src/ops', active = true, tabs = { { active = true, terminals = { term('t2') } } } },
      },
    }
    local space, folder = herdr.findSpace(layout, '/src/infra/main.ts', '/src/infra', { t1 = { '/src/infra/pulumi' } })
    assert(space and space.id == 's1' and folder == '/src/infra/pulumi')
    assert(herdr.findSpace(layout, '/src/infra/main.ts', '/src/infra', {}) == nil)
  end,
  ['findRelated lists the related agents, then terminals, by their live or start folder'] = function()
    ---@param terminal string
    ---@param app string|nil
    ---@return HerdrTerminal
    local function pane(terminal, app)
      return { terminal = terminal, pane = 'p' .. terminal, app = app }
    end
    local layout = {
      spaces = {
        { active = true, tabs = { { active = true, terminals = { pane('t1'), pane('t2', 'claude-code') } } } },
        { active = false, tabs = { { active = true, terminals = { pane('t3', 'copilot'), pane('t4', 'claude') } } } },
      },
    }
    local cwds = { t1 = { '/src/app' }, t2 = { '/src/web', '/src/app/pkg' }, t3 = { '/src/ops' }, t4 = { '/src/app' } }
    ---@type string[]
    local found = {}
    for _, match in ipairs(herdr.findRelated(layout, '/src/app/a.go', '/src/app', cwds)) do
      table.insert(found, match.terminal.terminal .. '=' .. match.folder)
    end
    assert(table.concat(found, ',') == 't2=/src/app/pkg,t4=/src/app,t1=/src/app', table.concat(found, ','))
    assert(#herdr.findRelated(layout, '/src/x/a.go', '/src/x', cwds) == 0)
  end,
  ['paneLabel shows the space, branch, tab and the pane name, else the agent and its session'] = function()
    ---@param terminal HerdrTerminal
    ---@return HerdrMatch
    local function match(terminal)
      return {
        terminal = terminal,
        space = { name = 'infra', active = true, tabs = {} },
        tab = { name = '2', active = true, terminals = {} },
        folder = '/src/infra',
      }
    end
    local agent = match({ terminal = 't1', app = 'claude-code' })
    assert(herdr.paneLabel(agent, 'main', 'Fix VPN alert') == 'infra - main - 2 - claude-code: Fix VPN alert')
    assert(herdr.paneLabel(agent, '', nil) == 'infra - 2 - claude-code')
    assert(herdr.paneLabel(match({ terminal = 't2', name = 'logs' }), 'main', 'x') == 'infra - main - 2 - logs')
    assert(herdr.paneLabel(match({ terminal = 't3' }), nil, nil) == 'infra - 2 - shell')
  end,
  ['agentArgv adds the prompt as the last argument, none when empty'] = function()
    local claude = { name = 'Claude Code', argv = { 'claude', '--verbose' } }
    assert(table.concat(herdr.agentArgv(claude, 'fix @a.go'), '|') == 'claude|--verbose|fix @a.go')
    assert(table.concat(herdr.agentArgv(claude, ' \n'), '|') == 'claude|--verbose')
    assert(#claude.argv == 2)
  end,
}
