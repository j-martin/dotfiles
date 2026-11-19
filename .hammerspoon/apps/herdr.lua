local logger = hs.logger.new('herdr', 'info')
local process = require 'utils/process'

---@class HerdrTerminal
---@field terminal string Address, e.g. `t4`.
---@field pane string|nil
---@field app string|nil Detected agent, e.g. `claude-code`.

---@class HerdrTab
---@field active boolean
---@field terminals HerdrTerminal[]

---@class HerdrSpace
---@field active boolean
---@field tabs HerdrTab[]

---@class HerdrLayout
---@field spaces HerdrSpace[]

---@class HerdrApp
---@field name string
---@field agentPatterns string[]
---@field focusedAt table<string, integer> When each agent terminal was last focused, higher is more recent.
---@field pollSeconds number Interval of the focus polling while Herdr is frontmost.
---@field findAgent fun(layout: HerdrLayout|nil, focusedAt: table<string, integer>|nil): HerdrTerminal|nil
---@field findPane fun(layout: HerdrLayout|nil, pane: string|nil): HerdrTerminal|nil
---@field reference fun(path: string, line: integer|nil, endLine: integer|nil, cwd: string|nil): string
---@field sendFileReference fun()
---@field onApplicationEvent fun(event: number)
---@field init fun()
local mod = {}

mod.name = 'Herdr'

mod.focusedAt = {}

mod.pollSeconds = 1

-- Matched against the agent `herdr-app ls` detects in each terminal
mod.agentPatterns = { 'claude', 'copilot' }

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

---@param address string
---@return string|nil
local function terminalCwd(address)
  local output = run('hc ls --json')
  local decoded = output and hs.json.decode(output)
  for _, terminal in ipairs(decoded and decoded.terminals or {}) do
    if terminal.address == address then
      return terminal.cwd
    end
  end
  return nil
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
  local decoded = status and hs.json.decode(status)
  local output = decoded and run('herdr-app ls')
  local terminal = output and mod.findPane(hs.json.decode(output), decoded.focused_pane)
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

--- Tracks the agent focused last while Herdr is frontmost, Herdr does not remember it.
---@param event number
function mod.onApplicationEvent(event)
  local watcher = hs.application.watcher
  if event == watcher.activated then
    poll(true)
  elseif event == watcher.deactivated or event == watcher.terminated then
    poll(false)
  end
end

function mod.init()
  local app = hs.application.frontmostApplication()
  poll(app ~= nil and app:name() == mod.name)
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

--- Pastes an `@` reference into the agent of the shown Herdr tab focused last, without pressing Enter: the focused editor or
--- Obsidian file and selected lines, or the working directory of Herdr, iTerm2 and Finder.
function mod.sendFileReference()
  local file = source(hs.window.focusedWindow())
  local path = file and file.path
  if not file or not path or not path:match('^/') then
    hs.alert.show('Herdr: no file or folder in the focused window')
    return
  end

  if hs.application.frontmostApplication():name() == mod.name then
    pcall(recordFocus)
  end
  local output = run('herdr-app ls')
  local agent = mod.findAgent(output and hs.json.decode(output), mod.focusedAt)
  if not agent then
    hs.alert.show('Herdr: no claude or copilot in the shown tab')
    return
  end

  local reference = mod.reference(path, file.line, file.endLine, terminalCwd(agent.terminal)) .. ' '
  local previous = hs.pasteboard.getContents()
  hs.pasteboard.setContents(reference)
  local pasted = run('herdr-app do pane.focus --terminal ' .. agent.terminal) and run('herdr-app do terminal.paste')
  hs.timer.doAfter(0.5, function()
    if previous then
      hs.pasteboard.setContents(previous)
    end
  end)
  if pasted then
    hs.alert.show('Herdr ' .. agent.terminal .. ': ' .. reference)
  else
    hs.alert.show('Herdr: could not paste, see logs')
  end
end

return mod
