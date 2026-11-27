local logger = hs.logger.new('herdr', 'info')
local process = require 'utils/process'
local markdown = require 'utils/markdown'

---@class HerdrTerminal
---@field terminal string Address, e.g. `t4`.
---@field pane string|nil
---@field app string|nil Detected agent, e.g. `claude-code`.
---@field status string|nil e.g. `working`, `done` once finished until seen then `idle`, or `blocked` when the agent
--- waits for input.
---@field name string|nil Name given to the pane.

---@class HerdrTab
---@field name string|nil
---@field active boolean
---@field terminals HerdrTerminal[]

---@class HerdrSpace
---@field id string|nil
---@field name string|nil
---@field folder string|nil
---@field active boolean
---@field tabs HerdrTab[]

---@class HerdrMatch
---@field terminal HerdrTerminal
---@field space HerdrSpace
---@field tab HerdrTab
---@field folder string Folder of the terminal relating to the path.

---@class HerdrTarget
---@field terminal string
---@field pane string Its own pane, or its parent's for a sub-agent without one.
---@field parent string|nil Set for a sub-agent without a pane, peeked over its parent's pane.

---@class HerdrNewAgent
---@field name string e.g. `Copilot`.
---@field argv string[] Command starting it.

---@class HerdrStatus
---@field focused_pane string|nil

---@class HerdrLayout
---@field spaces HerdrSpace[]

---@class HcTerminal
---@field address string e.g. `t4`.
---@field agent string|nil Program detected by `hc ls`, e.g. `copilot` or `zsh`.
---@field cwd string|nil Folder it was started in.
---@field parent string|nil Address of the agent that started this sub-agent.
---@field state string e.g. `live`.
---@field status string|nil e.g. `working` or `done`.
---@field turn integer|nil Turns the agent took, a new one once it is prompted again.
---@field where string|nil Herdr space and tab, e.g. `dotfiles / 1`.

---@class HerdrApp
---@field name string
---@field agentPatterns string[]
---@field focusedAt table<string, integer> When each agent terminal was last focused, higher is more recent.
---@field pollSeconds number Interval of the focus polling while Herdr is frontmost.
---@field findAgent fun(layout: HerdrLayout|nil, focusedAt: table<string, integer>|nil): HerdrTerminal|nil
---@field findPane fun(layout: HerdrLayout|nil, pane: string|nil): HerdrTerminal|nil
---@field findWaiting fun(layout: HerdrLayout|nil, focusedPane: string|nil, subAgents: HcTerminal[]|nil, peeked: string|nil): HerdrTarget|nil
---@field peeked HerdrTarget|nil Sub-agent `focusNext` peeked last, the current one while its parent's pane is focused.
---@field findDone fun(layout: HerdrLayout|nil, focusedPane: string|nil): HerdrTerminal|nil
---@field nextPane fun(layout: HerdrLayout|nil, focusedPane: string|nil): HerdrTerminal|nil
---@field focusNext fun()
---@field orderAgents fun(terminals: HcTerminal[], last: string|nil, preferred: string|nil, program: (fun(address: string): string|nil)|nil): HcTerminal[]
---@field rebase fun(prompt: string, reference: string, replacement: string): string
---@field withContext fun(prompt: string, context: AppContext|nil, selected: string|nil): string
---@field reference fun(path: string, line: integer|nil, endLine: integer|nil, cwd: string|nil): string
---@field sendFileReference fun()
---@field newAgent HerdrNewAgent Agent `sendFileReference` can start in the repo and space of what it prompts about.
---@field isUnder fun(path: string|nil, folder: string|nil): boolean
---@field repoRoot fun(path: string, exists: (fun(path: string): boolean)|nil): string|nil
---@field relates fun(folder: string|nil, path: string|nil, root: string|nil): boolean
---@field relatedFolder fun(folders: string[], path: string, root: string|nil): string|nil
---@field findRelated fun(layout: HerdrLayout|nil, path: string, root: string|nil, cwds: table<string, string[]>): HerdrMatch[]
---@field paneLabel fun(match: HerdrMatch, branch: string|nil, summary: string|nil): string
---@field focusSource fun()
---@field findSpace fun(layout: HerdrLayout|nil, path: string|nil, root: string|nil, cwds: table<string, string[]>|nil): HerdrSpace|nil, string|nil
---@field agentArgv fun(agent: HerdrNewAgent, prompt: string): string[]
---@field openKey { mods: string[], key: string } Herdr key running `mod.open:jm-open-file` (`~/.config/herdr-app/keys.json`).
---@field linkHandledFile string Touched by the `jm-open-file` mod's `link.js` on each link Herdr detects.
---@field cmdClickFile string Tells the `jm-open-file` mod a cmd-click opened it, to stay quiet.
---@field linkWaitSeconds number How long a cmd-click waits for `link.js` before falling back.
---@field isCmdClick fun(flags: table<string, boolean>): boolean
---@field onApplicationEvent fun(event: number)
---@field init fun()
local mod = {}

mod.name = 'Herdr'

mod.openKey = { mods = { 'cmd' }, key = 'o' }

mod.linkHandledFile = os.getenv('HOME') .. '/.cache/herdr-link-handled'

mod.cmdClickFile = os.getenv('HOME') .. '/.cache/herdr-cmd-click'

mod.linkWaitSeconds = 0.5

mod.focusedAt = {}

mod.pollSeconds = 1

-- hs.settings key of the agent picked last by `sendFileReference`, kept across reloads
local lastAgentKey = 'herdr.lastAgent'

-- Matched against the agent `herdr-app ls` detects in each terminal
mod.agentPatterns = { 'claude', 'copilot' }

mod.newAgent = { name = 'Claude Code', argv = { 'claude', '--model', 'opus' } }

---@param terminal HerdrTerminal
---@return boolean
local function isAgent(terminal)
  for _, pattern in ipairs(mod.agentPatterns) do
    if (terminal.app or ''):find(pattern, 1, true) then
      return true
    end
  end
  return false
end

---@param list table[]|nil
---@return table|nil
local function active(list)
  for _, item in ipairs(list or {}) do
    if item.active then
      return item
    end
  end
  return nil
end

--- Returns the agent of the shown tab focused last according to `focusedAt`, else its first agent, from the
--- `herdr-app ls` output.
---@param layout HerdrLayout|nil
---@param focusedAt table<string, integer>|nil
---@return HerdrTerminal|nil
function mod.findAgent(layout, focusedAt)
  local space = active(layout and layout.spaces) --[[@as HerdrSpace|nil]]
  local tab = space and active(space.tabs) --[[@as HerdrTab|nil]]
  ---@type HerdrTerminal|nil
  local found = nil
  local foundAt = -1
  for _, terminal in ipairs(tab and tab.terminals or {}) do
    local at = focusedAt and focusedAt[terminal.terminal] or 0
    if isAgent(terminal) and at > foundAt then
      found, foundAt = terminal, at
    end
  end
  return found
end

--- Returns the terminal shown in the pane, from the `herdr-app ls` output.
---@param layout HerdrLayout|nil
---@param pane string|nil
---@return HerdrTerminal|nil
function mod.findPane(layout, pane)
  for _, space in ipairs(pane and layout and layout.spaces or {}) do
    for _, tab in ipairs(space.tabs or {}) do
      for _, terminal in ipairs(tab.terminals or {}) do
        if terminal.pane == pane then
          return terminal
        end
      end
    end
  end
  return nil
end

--- Returns the terminal matching `include` in any space that comes after the focused pane, wrapping around, so
--- repeated calls cycle through them, from the `herdr-app ls` output.
---@param layout HerdrLayout|nil
---@param focusedPane string|nil
---@param include fun(terminal: HerdrTerminal): boolean
---@return HerdrTerminal|nil
local function cycle(layout, focusedPane, include)
  ---@type HerdrTerminal[]
  local waiting = {}
  ---@type integer
  local focusedIndex = 0
  for _, space in ipairs(layout and layout.spaces or {}) do
    for _, tab in ipairs(space.tabs or {}) do
      for _, terminal in ipairs(tab.terminals or {}) do
        if terminal.pane and include(terminal) then
          table.insert(waiting, terminal)
          if terminal.pane == focusedPane then
            focusedIndex = #waiting
          end
        end
      end
    end
  end
  if #waiting == 0 then
    return nil
  end
  return waiting[focusedIndex % #waiting + 1]
end

---@param status string|nil
---@return boolean
local function needsYou(status)
  return status == 'blocked' or status == 'error'
end

--- Returns the sub-agents without a pane of `parent` that need you, depth first, as targets peeked over its pane.
---@param parent string
---@param pane string
---@param subAgents HcTerminal[]
---@param panes table<string, boolean> Terminals that have a pane.
---@param found HerdrTarget[]
local function waitingSubAgents(parent, pane, subAgents, panes, found)
  for _, sub in ipairs(subAgents) do
    if sub.parent == parent and sub.state == 'live' and not panes[sub.address] then
      if needsYou(sub.status) then
        table.insert(found, { terminal = sub.address, pane = pane, parent = parent })
      end
      waitingSubAgents(sub.address, pane, subAgents, panes, found)
    end
  end
end

--- Returns the agent waiting for input (`blocked`) in any space that comes after the current one, wrapping around,
--- so repeated calls cycle through them, from the `herdr-app ls` output. Sub-agents without a pane needing you (from
--- `hc ls`) follow their parent, with its pane and their `parent`, to be peeked over it. The current one is
--- `peeked` when it is a sub-agent of the focused pane, else the focused pane.
---@param layout HerdrLayout|nil
---@param focusedPane string|nil
---@param subAgents HcTerminal[]|nil
---@param peeked string|nil
---@return HerdrTarget|nil
function mod.findWaiting(layout, focusedPane, subAgents, peeked)
  ---@type table<string, boolean>
  local panes = {}
  for _, space in ipairs(layout and layout.spaces or {}) do
    for _, tab in ipairs(space.tabs or {}) do
      for _, terminal in ipairs(tab.terminals or {}) do
        if terminal.pane then
          panes[terminal.terminal] = true
        end
      end
    end
  end
  ---@type HerdrTarget[]
  local waiting = {}
  for _, space in ipairs(layout and layout.spaces or {}) do
    for _, tab in ipairs(space.tabs or {}) do
      for _, terminal in ipairs(tab.terminals or {}) do
        if terminal.pane then
          if terminal.status == 'blocked' then
            table.insert(waiting, { terminal = terminal.terminal, pane = terminal.pane })
          end
          waitingSubAgents(terminal.terminal, terminal.pane, subAgents or {}, panes, waiting)
        end
      end
    end
  end
  if #waiting == 0 then
    return nil
  end
  ---@type integer
  local currentIndex = 0
  for index, target in ipairs(waiting) do
    if target.pane == focusedPane then
      if target.terminal == peeked then
        currentIndex = index
        break
      elseif not target.parent and currentIndex == 0 then
        currentIndex = index
      end
    end
  end
  return waiting[currentIndex % #waiting + 1]
end

--- Returns the agent that finished its turn and was not seen since (`done`, the blue dot) in any space that comes
--- after the focused pane, wrapping around, so repeated calls cycle through them, from the `herdr-app ls` output.
---@param layout HerdrLayout|nil
---@param focusedPane string|nil
---@return HerdrTerminal|nil
function mod.findDone(layout, focusedPane)
  return cycle(layout, focusedPane, function(terminal)
    return terminal.status == 'done'
  end)
end

--- Returns the agent still running its turn (`working`) in any space that comes after the focused pane, wrapping
--- around, so repeated calls cycle through them, from the `herdr-app ls` output.
---@param layout HerdrLayout|nil
---@param focusedPane string|nil
---@return HerdrTerminal|nil
function mod.findWorking(layout, focusedPane)
  return cycle(layout, focusedPane, function(terminal)
    return terminal.status == 'working'
  end)
end

--- Returns the terminal of the pane after the focused one in the shown tab, wrapping around, from the
--- `herdr-app ls` output.
---@param layout HerdrLayout|nil
---@param focusedPane string|nil
---@return HerdrTerminal|nil
function mod.nextPane(layout, focusedPane)
  local space = active(layout and layout.spaces) --[[@as HerdrSpace|nil]]
  local tab = space and active(space.tabs) --[[@as HerdrTab|nil]]
  ---@type HerdrTerminal[]
  local panes = {}
  ---@type integer
  local focusedIndex = 0
  for _, terminal in ipairs(tab and tab.terminals or {}) do
    if terminal.pane then
      table.insert(panes, terminal)
      if terminal.pane == focusedPane then
        focusedIndex = #panes
      end
    end
  end
  if #panes == 0 then
    return nil
  end
  return panes[focusedIndex % #panes + 1]
end

--- Returns the `@` file reference for agents, relative to their folder when inside it, with `#L<line>` or
--- `#L<line>-<endLine>`. Folders end with `/`, the agent folder itself is `./`.
---@param path string
---@param line integer|nil
---@param endLine integer|nil
---@param cwd string|nil
---@return string
function mod.reference(path, line, endLine, cwd)
  local file = path
  if cwd and cwd ~= '' then
    local prefix = cwd:gsub('/$', '') .. '/'
    if file:sub(1, #prefix) == prefix then
      file = file:sub(#prefix + 1)
      if file == '' then
        file = './'
      end
    end
  end
  local lines = ''
  if line then
    lines = '#L' .. line .. ((endLine and endLine > line) and ('-' .. endLine) or '')
  end
  return '@' .. file .. lines
end

---@param args string
---@return string|nil
local function run(args)
  local output, ok = process.execute(args .. ' 2>&1')
  if not ok then
    logger.ef('%s failed: %s', args, output)
    return nil
  end
  return output
end

---@class HcTerminalDetails
---@field cwd string|nil
---@field foreground { cwd: string|nil, argv: string[]|nil }|nil

---@param address string
---@return HcTerminalDetails|nil
local function terminalDetails(address)
  local output = run('hc get ' .. address .. ' --json')
  return output and hs.json.decode(output) --[[@as HcTerminalDetails|nil]]
end

--- Returns the live working directory of the terminal's foreground process, e.g. what its shell is in after a `cd`,
--- else the directory it was started in.
---@param details HcTerminalDetails|nil
---@return string|nil
local function detailsCwd(details)
  if not details then
    return nil
  end
  local foreground = details.foreground and details.foreground.cwd
  return (foreground and foreground ~= '') and foreground or details.cwd
end

---@param address string
---@return string|nil
local function terminalCwd(address)
  return detailsCwd(terminalDetails(address))
end

-- Every agent's session summary by terminal address, published by the `jm-pane` Herdr mod
local summariesFile = os.getenv('HOME') .. '/.config/herdr-app/shared.json'
local summariesKey = 'jm-pane.summaries'

---@return table<string, string>
local function summaries()
  local decoded = hs.json.read(summariesFile)
  return decoded and decoded[summariesKey] or {}
end

---@class HerdrSource
---@field path string Absolute path, folders end with `/`.
---@field line integer|nil
---@field endLine integer|nil

---@param path string|nil
---@return HerdrSource|nil
local function folder(path)
  if not path or path == '' then
    return nil
  end
  return { path = path:sub(-1) == '/' and path or path .. '/' }
end

--- Returns the working directory of the focused Herdr terminal.
---@return string|nil
local function focusedCwd()
  local status = run('herdr-app status')
  local decoded = status and hs.json.decode(status) --[[@as HerdrStatus|nil]]
  local output = decoded and run('herdr-app ls')
  local terminal = output and mod.findPane(hs.json.decode(output), decoded and decoded.focused_pane)
  return terminal and terminalCwd(terminal.terminal)
end

---@type integer
local focusCount = 0
---@type string|nil
local lastPane = nil
---@type hs.timer|nil
local pollTimer = nil

--- Records the focused pane's terminal in `focusedAt` when it runs an agent.
local function recordFocus()
  local output = process.execute('herdr-app status 2>/dev/null')
  local status = output ~= '' and hs.json.decode(output)
  local pane = status and status.focused_pane
  if not pane or pane == lastPane then
    return
  end
  lastPane = pane
  local layout = hs.json.decode((process.execute('herdr-app ls 2>/dev/null')))
  local terminal = mod.findPane(layout, pane)
  if terminal and isAgent(terminal) then
    focusCount = focusCount + 1
    mod.focusedAt[terminal.terminal] = focusCount
  end
end

---@param frontmost boolean
local function poll(frontmost)
  if pollTimer then
    pollTimer:stop()
    pollTimer = nil
  end
  if frontmost then
    lastPane = nil
    pcall(recordFocus)
    pollTimer = hs.timer.doEvery(mod.pollSeconds, function()
      pcall(recordFocus)
    end)
  end
end

--- True for a click with cmd as the only modifier.
---@param flags table<string, boolean>
---@return boolean
function mod.isCmdClick(flags)
  return flags.cmd == true and not (flags.alt or flags.shift or flags.ctrl or flags.fn)
end

---@type hs.eventtap|nil
local clickTap = nil
---@type hs.timer|nil
local fallbackTimer = nil
---@type boolean
local cmdClicked = false

--- Shift-double-clicks at the point, which selects the word and focuses its pane. Shift bypasses mouse reporting
--- of programs like Copilot CLI or pagers; Herdr reads the live modifier state, so shift is pressed, not just flagged.
---@param point { x: number, y: number }
local function doubleClick(point)
  local types = hs.eventtap.event.types
  local clickState = hs.eventtap.event.properties.mouseEventClickState
  hs.eventtap.event.newKeyEvent('shift', true):post()
  for count = 1, 2 do
    for _, type in ipairs({ types.leftMouseDown, types.leftMouseUp }) do
      hs.eventtap.event.newMouseEvent(type, point):setFlags({ shift = true }):setProperty(clickState, count):post()
    end
  end
  hs.eventtap.event.newKeyEvent('shift', false):post()
end

--- Opens the word at the point with the `jm-open-file` mod, which reads it and its line.
---@param point { x: number, y: number }
local function openAt(point)
  local marker = io.open(mod.cmdClickFile, 'w')
  if not marker then
    logger.e('Cannot write ' .. mod.cmdClickFile)
    return
  end
  marker:close()
  doubleClick(point)
  hs.timer.doAfter(0.1, function()
    hs.eventtap.keyStroke(mod.openKey.mods, mod.openKey.key, 0)
  end)
end

--- Cmd-click in Herdr goes to the `jm-open-file` mod's `link.js` for what Herdr detects as a link. Herdr skips
--- bare filenames and cannot tell a mod where a click was, so when `link.js` did not run, open the word under the
--- pointer. The click itself is left to Herdr.
---@param event hs.eventtap.event
---@return boolean
local function onClick(event)
  if event:getType() == hs.eventtap.event.types.leftMouseDown then
    cmdClicked = mod.isCmdClick(event:getFlags())
    if cmdClicked then
      os.remove(mod.linkHandledFile)
    end
    return false
  end
  if not cmdClicked then
    return false
  end
  cmdClicked = false
  local point = event:location()
  if fallbackTimer then
    fallbackTimer:stop()
  end
  fallbackTimer = hs.timer.doAfter(mod.linkWaitSeconds, function()
    fallbackTimer = nil
    if not hs.fs.attributes(mod.linkHandledFile) then
      openAt(point)
    end
  end)
  return false
end

---@param frontmost boolean
local function tapClicks(frontmost)
  if not clickTap then
    local types = hs.eventtap.event.types
    clickTap = hs.eventtap.new({ types.leftMouseDown, types.leftMouseUp }, onClick)
  end
  if frontmost then
    clickTap:start()
  else
    cmdClicked = false
    clickTap:stop()
  end
end

--- Tracks the agent focused last while Herdr is frontmost, Herdr does not remember it, and opens the file under
--- the pointer on cmd-clicks Herdr does not detect as links.
---@param event number
function mod.onApplicationEvent(event)
  local watcher = hs.application.watcher
  if event == watcher.activated then
    poll(true)
    tapClicks(true)
  elseif event == watcher.deactivated or event == watcher.terminated then
    poll(false)
    tapClicks(false)
  end
end

function mod.init()
  local app = hs.application.frontmostApplication()
  local frontmost = app ~= nil and app:name() == mod.name
  poll(frontmost)
  tapClicks(frontmost)
end

--- Switches to Herdr like other apps and focuses, in priority order, cycling within a level on each call and falling
--- to the next one only when the current level has nothing else:
--- 1. Needs you: agents of every space waiting for input (`blocked`), peeking at sub-agents without a pane that need
---    you (`blocked` or `error`) over their parent's.
--- 2. Done: agents of every space done and not seen since (`done`, blue).
--- 3. Working: agents of every space still running their turn (`working`).
--- 4. While Herdr is frontmost, the next pane of the shown tab.
function mod.focusNext()
  local app = hs.application.get(mod.name)
  local layout = app and run('herdr-app ls')
  local status = layout and run('herdr-app status')
  local decoded = status and hs.json.decode(status) --[[@as HerdrStatus|nil]]
  local focusedPane = decoded and decoded.focused_pane
  local parsed = layout and hs.json.decode(layout) --[[@as HerdrLayout|nil]]
  local listed = parsed and run('hc ls --json')
  local subAgents = listed and hs.json.decode(listed)
  local peeked = mod.peeked and mod.peeked.pane == focusedPane and mod.peeked.terminal or nil
  ---@type HerdrTarget|HerdrTerminal|nil
  local target = mod.findWaiting(parsed, focusedPane, subAgents and subAgents.terminals, peeked)
  local frontmost = app ~= nil and hs.application.frontmostApplication() == app
  ---@param shown HerdrTarget|HerdrTerminal
  ---@return boolean
  local function current(shown)
    if shown.pane ~= focusedPane then
      return false
    end
    if shown.parent then
      return shown.terminal == peeked
    end
    return peeked == nil
  end
  if parsed and (not target or current(target)) then
    target = mod.findDone(parsed, focusedPane) or target
  end
  if parsed and (not target or current(target)) then
    target = mod.findWorking(parsed, focusedPane) or target
  end
  if frontmost and (not target or current(target)) then
    target = mod.nextPane(parsed, focusedPane)
  end
  if not app or not target or not target.pane or current(target) then
    require('windows').launchOrCycleFocus(mod.name)()
    return
  end
  app:activate()
  run('herdr-app do pane.focus --pane ' .. target.pane)
  mod.peeked = target.parent and target --[[@as HerdrTarget]] or nil
  if mod.peeked then
    run('herdr-app do terminal.peek --terminal ' .. mod.peeked.terminal)
  end
end

--- Returns what the focused window shows: the working directory of terminals and Finder, the active Obsidian note,
--- or the file and selected lines of editors.
---@param window hs.window|nil
---@return HerdrSource|nil
local function source(window)
  local apps = require 'apps'
  local appName = window and window:application():name()
  if appName == mod.name then
    return folder(focusedCwd())
  elseif appName == apps.iterm.name then
    return folder(apps.iterm.workdir())
  elseif appName == apps.finder.name then
    return folder(apps.finder.folder())
  elseif appName == apps.obsidian.name then
    return apps.obsidian.activeFile() --[[@as HerdrSource|nil]]
  end
  local context = apps.context(window)
  return context and context.path and context --[[@as HerdrSource]]
end

--- Orders the live `hc` agents: the one picked last, then `preferred` (the agent of the shown Herdr tab focused last),
--- then the others as listed. Terminals not running claude or copilot are left out. `hc ls` only names the agent once
--- it reported a status, else it names the foreground process, e.g. `2.1.332` for a Claude Code not prompted yet, so
--- `program` gives the command the terminal's foreground process was started with, to recognize those.
---@param terminals HcTerminal[]
---@param last string|nil Address picked last.
---@param preferred string|nil
---@param program (fun(address: string): string|nil)|nil
---@return HcTerminal[]
function mod.orderAgents(terminals, last, preferred, program)
  ---@type HcTerminal[]
  local agents = {}
  for _, terminal in ipairs(terminals) do
    if
      terminal.state == 'live'
      and (
        isAgent({ terminal = terminal.address, app = terminal.agent })
        or (program and isAgent({ terminal = terminal.address, app = program(terminal.address) }))
      )
    then
      table.insert(agents, terminal)
    end
  end
  ---@param terminal HcTerminal
  ---@return integer
  local function rank(terminal)
    return terminal.address == last and 0 or terminal.address == preferred and 1 or 2
  end
  ---@type table<string, integer>
  local position = {}
  for index, terminal in ipairs(agents) do
    position[terminal.address] = index
  end
  table.sort(agents, function(a, b)
    if rank(a) ~= rank(b) then
      return rank(a) < rank(b)
    end
    return position[a.address] < position[b.address]
  end)
  return agents
end

--- Replaces the leading `reference` of the prompt with `replacement`, e.g. relative to the folder of another agent.
---@param prompt string
---@param reference string
---@param replacement string
---@return string
function mod.rebase(prompt, reference, replacement)
  if prompt:sub(1, #reference) == reference then
    return replacement .. prompt:sub(#reference + 1)
  end
  return prompt
end

--- Returns the prompt followed by what the window shows, its title, URL and details, and the selection as a quote.
---@param prompt string
---@param context AppContext|nil
---@param selected string|nil
---@return string
function mod.withContext(prompt, context, selected)
  ---@type string[]
  local parts = {}
  local typed = prompt:gsub('%s+$', '')
  if typed ~= '' then
    table.insert(parts, typed)
  end
  if context then
    local lines = { context.title }
    if context.url then
      table.insert(lines, context.url)
    end
    for _, detail in ipairs(context.details or {}) do
      table.insert(lines, detail)
    end
    table.insert(parts, table.concat(lines, '\n'))
  end
  if selected and selected:match('%S') then
    table.insert(parts, markdown.quote((selected:gsub('^%s*\n', ''))))
  end
  return table.concat(parts, '\n\n')
end

---@type hs.chooser|nil
local chooser = nil

---@type hs.chooser|nil
local picker = nil

-- hs.settings key of how `sendFileReference` sent its last prompt, `paste` or `submit`
local lastModeKey = 'herdr.lastMode'

--- True when the path is the folder or inside it.
---@param path string|nil
---@param folder string|nil
---@return boolean
function mod.isUnder(path, folder)
  if not path or not folder or folder == '' then
    return false
  end
  local prefix = folder:gsub('/+$', '')
  local trimmed = path:gsub('/+$', '')
  return trimmed == prefix or trimmed:sub(1, #prefix + 1) == prefix .. '/'
end

--- Returns the closest folder holding the path with a `.git`, its repo or worktree root.
---@param path string
---@param exists (fun(path: string): boolean)|nil Defaults to checking the file system.
---@return string|nil
function mod.repoRoot(path, exists)
  exists = exists or function(candidate)
    return hs.fs.attributes(candidate) ~= nil
  end
  local dir = path:gsub('/+$', '')
  while dir ~= '' do
    if exists(dir .. '/.git') then
      return dir
    end
    dir = dir:match('^(.*)/[^/]*$') or ''
  end
  return nil
end

--- True when an agent or space in the folder is about the path: inside its repo root, else holding the path.
---@param folder string|nil
---@param path string|nil
---@param root string|nil Repo root of the path.
---@return boolean
function mod.relates(folder, path, root)
  if root then
    return mod.isUnder(folder, root)
  end
  return mod.isUnder(path, folder)
end

--- Returns the deepest of the folders relating to the path, see `relates`.
---@param folders string[]
---@param path string
---@param root string|nil Repo root of the path.
---@return string|nil
function mod.relatedFolder(folders, path, root)
  ---@type string|nil
  local deepest = nil
  for _, folder in ipairs(folders) do
    if mod.relates(folder, path, root) and (not deepest or #folder > #deepest) then
      deepest = folder
    end
  end
  return deepest
end

--- Returns the space a new agent about the path goes in, from the `herdr-app ls` output, and its folder relating to
--- the path. A space relates by its folder or the live folder of one of its terminals, Herdr names it after where its
--- first terminal is. The shown space wins when it relates, else the one with the deepest related folder. Without a
--- path, the shown space.
---@param layout HerdrLayout|nil
---@param path string|nil
---@param root string|nil Repo root of the path.
---@param cwds table<string, string[]>|nil Live and start folders of each terminal by address.
---@return HerdrSpace|nil
---@return string|nil
function mod.findSpace(layout, path, root, cwds)
  local spaces = layout and layout.spaces or {}
  if not path then
    local shown = active(spaces) --[[@as HerdrSpace|nil]]
    return shown, shown and shown.folder
  end
  ---@type HerdrSpace|nil
  local found = nil
  ---@type string|nil
  local foundFolder = nil
  for _, space in ipairs(spaces) do
    ---@type string[]
    local folders = { space.folder }
    for _, tab in ipairs(space.tabs or {}) do
      for _, terminal in ipairs(tab.terminals or {}) do
        for _, cwd in ipairs(cwds and cwds[terminal.terminal] or {}) do
          table.insert(folders, cwd)
        end
      end
    end
    local deepest = mod.relatedFolder(folders, path, root)
    if deepest then
      if space.active then
        return space, deepest
      end
      if not foundFolder or #deepest > #foundFolder then
        found, foundFolder = space, deepest
      end
    end
  end
  return found, foundFolder
end

--- Shows a picker of the choices once the one calling it closed, its query an editable text that does not filter
--- them, then calls back with the picked one, nil when dismissed, and the text.
---@param choices table[]
---@param placeholder string
---@param query string
---@param callback fun(choice: table|nil, query: string)
local function pick(choices, placeholder, query, callback)
  hs.timer.doAfter(0, function()
    if picker then
      picker:delete()
    end
    picker = hs.chooser.new(function(choice)
      callback(choice, picker and picker:query() or '')
    end)
    picker:bgDark(true)
    picker:placeholderText(placeholder)
    picker:queryChangedCallback(function() end)
    picker:choices(choices)
    picker:query(query)
    picker:show()
  end)
end

--- Returns the command starting the agent with the prompt as its first message, without it when empty.
---@param agent HerdrNewAgent
---@param prompt string
---@return string[]
function mod.agentArgv(agent, prompt)
  local argv = table.move(agent.argv, 1, #agent.argv, 1, {})
  if prompt:match('%S') then
    table.insert(argv, prompt)
  end
  return argv
end

--- Pastes the prompt into the agent's Herdr pane without pressing Enter, and brings Herdr forward to finish it.
--- herdr-core can only paste and submit, so the paste goes through the Herdr window and the pasteboard.
---@param agent HcTerminal
---@param prompt string
local function paste(agent, prompt)
  if not run('herdr-app do pane.focus --terminal ' .. agent.address) then
    hs.alert.show('Herdr: ' .. agent.address .. ' is not in the Herdr window, submit it instead')
    return
  end
  local previous = hs.pasteboard.getContents()
  hs.pasteboard.setContents(prompt)
  local pasted = run('herdr-app do terminal.paste')
  hs.timer.doAfter(0.5, function()
    if previous then
      hs.pasteboard.setContents(previous)
    end
  end)
  local app = hs.application.get(mod.name)
  if app then
    app:activate()
  end
  if not pasted then
    hs.alert.show('Herdr: could not paste into ' .. agent.address .. ', see logs')
  end
end

--- Sends the prompt to the agent with Enter, and shows its pane in Herdr when it is there.
---@param agent HcTerminal
---@param prompt string
local function submit(agent, prompt)
  run('herdr-app do pane.focus --terminal ' .. agent.address)
  process.start('hc', { 'send', agent.address, prompt }, nil, 60, {
    quiet = true,
    callback = function(exitCode, stdOut, stdErr)
      if exitCode == 0 then
        hs.alert.show('Herdr ' .. agent.address .. ': ' .. prompt)
      else
        logger.ef('hc send %s failed: %s %s', agent.address, stdOut, stdErr)
        hs.alert.show('Herdr: could not send to ' .. agent.address .. ', see logs')
      end
    end,
  })
end

--- Returns the panes of all spaces and tabs about the path, from the `herdr-app ls` output: the agents, then the
--- other terminals, each in layout order. A terminal relates by its live folder or the one it started in.
---@param layout HerdrLayout|nil
---@param path string
---@param root string|nil Repo root of the path.
---@param cwds table<string, string[]> Live and start folders of each terminal by address.
---@return HerdrMatch[]
function mod.findRelated(layout, path, root, cwds)
  ---@type HerdrMatch[]
  local agents = {}
  ---@type HerdrMatch[]
  local others = {}
  for _, space in ipairs(layout and layout.spaces or {}) do
    for _, tab in ipairs(space.tabs or {}) do
      for _, terminal in ipairs(tab.terminals or {}) do
        local folder = terminal.pane and mod.relatedFolder(cwds[terminal.terminal] or {}, path, root)
        if folder then
          table.insert(
            isAgent(terminal) and agents or others,
            { terminal = terminal, space = space, tab = tab, folder = folder }
          )
        end
      end
    end
  end
  return table.move(others, 1, #others, #agents + 1, agents)
end

--- Returns the live folder, then the start folder when another, of each terminal of the `herdr-app ls` output by
--- address.
---@param layout HerdrLayout|nil
---@return table<string, string[]>
local function terminalFolders(layout)
  ---@type table<string, string[]>
  local cwds = {}
  for _, space in ipairs(layout and layout.spaces or {}) do
    for _, tab in ipairs(space.tabs or {}) do
      for _, terminal in ipairs(tab.terminals or {}) do
        local details = terminalDetails(terminal.terminal)
        ---@type string[]
        local folders = {}
        for _, folder in ipairs({ detailsCwd(details) or false, details and details.cwd or false }) do
          if folder and folder ~= '' and folder ~= folders[1] then
            table.insert(folders, folder)
          end
        end
        cwds[terminal.terminal] = folders
      end
    end
  end
  return cwds
end

--- Returns `<space> - <branch> - <tab> - <pane>` for a picker row, without the branch when empty. The pane is its
--- name, else the agent and its session summary, else `shell`.
---@param match HerdrMatch
---@param branch string|nil
---@param summary string|nil
---@return string
function mod.paneLabel(match, branch, summary)
  local terminal = match.terminal
  local pane = terminal.name
  if not pane or pane == '' then
    pane = terminal.app or 'shell'
    if summary and summary ~= '' then
      pane = pane .. ': ' .. summary
    end
  end
  ---@type string[]
  local parts = { match.space.name or match.space.folder or '?' }
  if branch and branch ~= '' then
    table.insert(parts, branch)
  end
  table.insert(parts, match.tab.name or '?')
  table.insert(parts, pane)
  return table.concat(parts, ' - ')
end

---@type hs.chooser|nil
local paneChooser = nil

---@param pane string
local function focusPane(pane)
  local app = hs.application.get(mod.name)
  if app then
    app:activate()
  end
  run('herdr-app do pane.focus --pane ' .. pane)
end

--- Shows the Herdr pane about what the focused window shows, e.g. the GoLand file: in its repo, else holding it, by
--- the live or start folder of its terminal, in any space and tab. A picker lists them, agents first, when several
--- match. Without one, the space about it, else just Herdr.
function mod.focusSource()
  local file = source(hs.window.focusedWindow())
  local path = file and file.path
  if not path or not path:match('^/') then
    hs.alert.show('Herdr: no file or folder in the focused window')
    return
  end
  local app = hs.application.get(mod.name)
  local layout = app and run('herdr-app ls')
  local parsed = layout and hs.json.decode(layout) --[[@as HerdrLayout|nil]]
  if not app or not parsed then
    require('windows').launchOrCycleFocus(mod.name)()
    return
  end
  local root = mod.repoRoot(path)
  local cwds = terminalFolders(parsed)
  local matches = mod.findRelated(parsed, path, root, cwds)
  if #matches == 1 then
    focusPane(matches[1].terminal.pane)
    return
  end
  if #matches == 0 then
    app:activate()
    local space = mod.findSpace(parsed, path, root, cwds)
    if space and space.id then
      run('herdr-app do space.select --id ' .. space.id)
    else
      hs.alert.show('Herdr: nothing about ' .. (root or path))
    end
    return
  end

  local described = summaries()
  ---@type table<string, string>
  local branches = {}
  ---@type table[]
  local choices = {}
  for _, match in ipairs(matches) do
    local terminal = match.terminal
    if not branches[match.folder] then
      branches[match.folder] = (process.execute(
        'git -C ' .. string.format('%q', match.folder) .. ' branch --show-current 2>/dev/null'
      )):gsub('%s+$', '')
    end
    table.insert(choices, {
      text = mod.paneLabel(match, branches[match.folder], described[terminal.terminal]),
      subText = string.format('%s %s  %s', terminal.terminal, terminal.status or '', match.folder),
      pane = terminal.pane,
    })
  end
  if paneChooser then
    paneChooser:delete()
  end
  paneChooser = hs.chooser.new(function(choice)
    if choice then
      focusPane(choice.pane)
    end
  end)
  paneChooser:bgDark(true)
  paneChooser:placeholderText('Herdr pane about ' .. (root or path))
  paneChooser:choices(choices)
  paneChooser:show()
end

--- Starts the agent with the prompt as its first message in a new tab of the space, or in a new space without one.
---@param agent HerdrNewAgent
---@param space string|nil Space id.
---@param folder string|nil
---@param prompt string
local function startAgent(agent, space, folder, prompt)
  local command = space and 'tab.new' or 'space.new'
  local args = { space = space, folder = folder, argv = mod.agentArgv(agent, prompt) }
  process.start('herdr-app', { 'do', command, hs.json.encode(args) }, nil, 30, {
    quiet = true,
    callback = function(exitCode, stdOut, stdErr)
      local decoded = exitCode == 0 and hs.json.decode(stdOut)
      if not decoded or not decoded.terminal then
        logger.ef('herdr-app do %s failed: %s %s', command, stdOut, stdErr)
        hs.alert.show('Herdr: could not start ' .. agent.name .. ', see logs')
        return
      end
      hs.settings.set(lastAgentKey, decoded.terminal)
      hs.alert.show('Herdr ' .. decoded.terminal .. ': ' .. prompt)
    end,
  })
end

--- Shows a picker prefilled with an `@` reference to what the focused window shows, the editor or Obsidian file and
--- selected lines, or the working directory of Herdr, iTerm2 and Finder, to type the rest of the prompt after it.
--- Other apps, e.g. Brave, add what their window shows, like its URL, and the selection as a quote after the prompt.
--- Lists the agents about the same repo, else holding the path, then a row starting a new agent with the prompt in
--- that repo and its space, then the other agents, each in order of `orderAgents`. Without a path, every agent comes
--- first and the new one goes in the shown space. A second picker, the prompt still editable, pastes it into the
--- agent without Enter or submits it, the way picked last first; a new agent can only be submitted to.
function mod.sendFileReference()
  local window = hs.window.focusedWindow()
  local file = source(window)
  local path = file and file.path
  ---@type AppContext|nil
  local context = nil
  ---@type string|nil
  local selected = nil
  if not path or not path:match('^/') then
    path = nil
    context = require('apps').windowContext(window)
    selected = context and context.selection or require('selection').getSelectedText()
    if not context and selected == '' then
      hs.alert.show('Herdr: nothing to prompt about in the focused window')
      return
    end
  end

  if hs.application.frontmostApplication():name() == mod.name then
    pcall(recordFocus)
  end
  local layout = run('herdr-app ls')
  local parsed = layout and hs.json.decode(layout) --[[@as HerdrLayout|nil]]
  local shown = mod.findAgent(parsed, mod.focusedAt)
  local listed = run('hc ls --json')
  local decoded = listed and hs.json.decode(listed)
  ---@param address string
  ---@return string|nil
  local function program(address)
    local details = terminalDetails(address)
    local argv = details and details.foreground and details.foreground.argv
    return argv and argv[1] and argv[1]:match('[^/]+$')
  end
  local agents = mod.orderAgents(
    decoded and decoded.terminals or {},
    hs.settings.get(lastAgentKey),
    shown and shown.terminal,
    program
  )

  local root = path and mod.repoRoot(path)
  local cwds = path and terminalFolders(parsed) or {}
  local space, spaceFolder = mod.findSpace(parsed, path, root, cwds)
  local newFolder = root or spaceFolder or (path and path:match('^(.*)/[^/]*$'))
  local newReference = (file and path) and mod.reference(path, file.line, file.endLine, newFolder) or ''

  ---@type table<string, string>
  local references = {}
  ---@type table[]
  local related = {}
  ---@type table[]
  local others = {}
  local described = summaries()
  local attached = context and ('  ·  📎 ' .. context.title) or ''
  for _, agent in ipairs(agents) do
    local cwd = (cwds[agent.address] or {})[1] or detailsCwd(terminalDetails(agent.address)) or agent.cwd
    local description = described[agent.address] or ''
    references[agent.address] = (file and path) and mod.reference(path, file.line, file.endLine, cwd) or ''
    local details =
      string.format('%s %s  %s  %s  %s', agent.agent, agent.address, agent.status or '', agent.where or '', cwd or '')
    table.insert((not path or mod.relates(cwd, path, root)) and related or others, {
      text = description ~= '' and description or string.format('%s %s', agent.agent, agent.address),
      subText = details .. attached,
      address = agent.address,
    })
  end
  local where = space and string.format('a new tab of %s', space.name or space.folder or '') or 'a new space'
  ---@type table[]
  local choices = related
  table.insert(choices, {
    text = 'New ' .. mod.newAgent.name .. ' agent',
    subText = string.format('In %s  ·  %s', where, newFolder or '~') .. attached,
    new = true,
  })
  for _, choice in ipairs(others) do
    table.insert(choices, choice)
  end
  local reference = related[1] and related[1].address and references[related[1].address] or newReference

  ---@param prompt string
  ---@param replacement string
  ---@return string
  local function finish(prompt, replacement)
    return path and mod.rebase(prompt, reference, replacement) or mod.withContext(prompt, context, selected)
  end

  --- Picks pasting the prompt without Enter or submitting it, the way picked last first, the prompt still editable.
  --- Without `pasteable`, only submitting is offered.
  ---@param name string Agent it goes to.
  ---@param prompt string As typed in the first picker.
  ---@param replacement string `@` reference relative to the agent folder.
  ---@param pasteable boolean
  ---@param deliver fun(prompt: string, submitted: boolean)
  local function send(name, prompt, replacement, pasteable, deliver)
    local modes = {
      { text = 'Paste', subText = name .. ', without Enter to finish it in Herdr', mode = 'paste' },
      { text = 'Submit ⏎', subText = name .. ', with Enter', mode = 'submit' },
    }
    if not pasteable then
      table.remove(modes, 1)
    elseif hs.settings.get(lastModeKey) == 'submit' then
      modes[1], modes[2] = modes[2], modes[1]
    end
    pick(modes, 'Prompt, ⏎ sends it to ' .. name, prompt, function(choice, edited)
      if window and (not choice or choice.mode == 'submit') then
        window:focus()
      end
      if not choice then
        return
      end
      if pasteable then
        hs.settings.set(lastModeKey, choice.mode)
      end
      deliver(finish(edited, replacement), choice.mode == 'submit')
    end)
  end

  if chooser then
    chooser:delete()
  end
  chooser = hs.chooser.new(function(choice)
    local prompt = chooser and chooser:query() or ''
    if not choice then
      if window then
        window:focus()
      end
      return
    end
    if choice.new then
      send('New ' .. mod.newAgent.name .. ' agent', prompt, newReference, false, function(text)
        startAgent(mod.newAgent, space and space.id, newFolder, text)
      end)
      return
    end
    for _, agent in ipairs(agents) do
      if agent.address == choice.address then
        send(choice.text, prompt, references[agent.address], true, function(text, submitted)
          hs.settings.set(lastAgentKey, agent.address)
          if submitted then
            submit(agent, text)
          else
            paste(agent, text)
          end
        end)
        return
      end
    end
  end)
  chooser:bgDark(true)
  chooser:placeholderText('Prompt, ⏎ picks the highlighted agent, or starts a new one')
  -- Typing writes the prompt, it does not filter the agents.
  chooser:queryChangedCallback(function() end)
  chooser:choices(choices)
  chooser:query(path and (reference .. ' ') or '')
  chooser:show()
end

return mod
