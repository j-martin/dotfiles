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
---@field findAgent fun(layout: HerdrLayout|nil): HerdrTerminal|nil
---@field reference fun(path: string, line: integer|nil, endLine: integer|nil, cwd: string|nil): string
---@field sendFileReference fun()
local mod = {}

mod.name = 'Herdr'

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

--- Returns the first agent of the shown tab, from the `herdr-app ls` output.
---@param layout HerdrLayout|nil
---@return HerdrTerminal|nil
function mod.findAgent(layout)
  local space = active(layout and layout.spaces) --[[@as HerdrSpace|nil]]
  local tab = space and active(space.tabs) --[[@as HerdrTab|nil]]
  for _, terminal in ipairs(tab and tab.terminals or {}) do
    if isAgent(terminal) then
      return terminal
    end
  end
  return nil
end

--- Returns the `@` file reference for agents, relative to their folder when inside it, with `#L<line>` or
--- `#L<line>-<endLine>`.
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

--- Pastes an `@` reference to the focused editor file and selected lines into the agent of the shown Herdr tab, without pressing Enter.
function mod.sendFileReference()
  local apps = require 'apps'
  local context = apps.context(hs.window.focusedWindow())
  local path = context and context.path
  if not context or not path or not path:match('^/') then
    hs.alert.show('Herdr: no file in the focused window')
    return
  end

  local output = run('herdr-app ls')
  local agent = mod.findAgent(output and hs.json.decode(output))
  if not agent then
    hs.alert.show('Herdr: no claude or copilot in the shown tab')
    return
  end

  local reference = mod.reference(path, context.line, context.endLine, terminalCwd(agent.terminal)) .. ' '
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
