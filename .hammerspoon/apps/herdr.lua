local logger = hs.logger.new('herdr', 'info')
local process = require 'utils/process'
local markdown = require 'utils/markdown'

---@class HerdrTerminal
---@field terminal string Address, e.g. `t4`.
---@field pane string|nil
---@field app string|nil Detected agent, e.g. `claude-code`.
---@field status string|nil e.g. `working`, `idle` or `blocked` when the agent waits for input.

---@class HerdrTab
---@field active boolean
---@field terminals HerdrTerminal[]

---@class HerdrSpace
---@field active boolean
---@field tabs HerdrTab[]

---@class HerdrStatus
---@field focused_pane string|nil

---@class HerdrLayout
---@field spaces HerdrSpace[]

---@class HcTerminal
---@field address string e.g. `t4`.
---@field agent string|nil Program detected by `hc ls`, e.g. `copilot` or `zsh`.
---@field cwd string|nil Folder it was started in.
---@field state string e.g. `live`.
---@field status string|nil e.g. `working` or `done`.
---@field where string|nil Herdr space and tab, e.g. `dotfiles / 1`.

---@class HerdrApp
---@field name string
---@field agentPatterns string[]
---@field focusedAt table<string, integer> When each agent terminal was last focused, higher is more recent.
---@field pollSeconds number Interval of the focus polling while Herdr is frontmost.
---@field findAgent fun(layout: HerdrLayout|nil, focusedAt: table<string, integer>|nil): HerdrTerminal|nil
---@field findPane fun(layout: HerdrLayout|nil, pane: string|nil): HerdrTerminal|nil
---@field findWaiting fun(layout: HerdrLayout|nil, focusedPane: string|nil): HerdrTerminal|nil
---@field focusWaiting fun()
---@field orderAgents fun(terminals: HcTerminal[], last: string|nil, preferred: string|nil): HcTerminal[]
---@field rebase fun(prompt: string, reference: string, replacement: string): string
---@field withContext fun(prompt: string, context: AppContext|nil, selected: string|nil): string
---@field reference fun(path: string, line: integer|nil, endLine: integer|nil, cwd: string|nil): string
---@field sendFileReference fun()
---@field openKey { mods: string[], key: string } Herdr key running `mod.open:jm-open-file` (`~/.config/herdr-app/keys.json`).
---@field isCmdClick fun(flags: table<string, boolean>): boolean
---@field onApplicationEvent fun(event: number)
---@field init fun()
local mod = {}

mod.name = 'Herdr'

mod.openKey = { mods = { 'cmd' }, key = 'o' }

mod.focusedAt = {}

mod.pollSeconds = 1

-- hs.settings key of the agent picked last by `sendFileReference`, kept across reloads
local lastAgentKey = 'herdr.lastAgent'

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

--- Returns the agent waiting for input (`blocked`) in any space that comes after the focused pane, wrapping around,
--- so repeated calls cycle through them, from the `herdr-app ls` output.
---@param layout HerdrLayout|nil
---@param focusedPane string|nil
---@return HerdrTerminal|nil
function mod.findWaiting(layout, focusedPane)
  ---@type HerdrTerminal[]
  local waiting = {}
  ---@type integer
  local focusedIndex = 0
  for _, space in ipairs(layout and layout.spaces or {}) do
    for _, tab in ipairs(space.tabs or {}) do
      for _, terminal in ipairs(tab.terminals or {}) do
        if terminal.status == 'blocked' and terminal.pane then
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
---@field foreground { cwd: string|nil }|nil

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
---@type boolean
local swallowUp = false

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

--- Cmd-click in Herdr opens the file under the pointer: Herdr cannot tell a mod where a click was,
--- so select the word with a double-click and let the `jm-open-file` mod read it and its line.
---@param event hs.eventtap.event
---@return boolean
local function onClick(event)
  local types = hs.eventtap.event.types
  if event:getType() == types.leftMouseUp then
    local swallow = swallowUp
    swallowUp = false
    return swallow
  end
  if not mod.isCmdClick(event:getFlags()) then
    return false
  end
  swallowUp = true
  local point = event:location()
  hs.timer.doAfter(0, function()
    doubleClick(point)
    hs.timer.doAfter(0.1, function()
      hs.eventtap.keyStroke(mod.openKey.mods, mod.openKey.key, 0)
    end)
  end)
  return true
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
    swallowUp = false
    clickTap:stop()
  end
end

--- Tracks the agent focused last while Herdr is frontmost, Herdr does not remember it, and turns cmd-click into
--- opening the file under the pointer.
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

--- Switches to Herdr like other apps and, when an agent waits for input in any space, focuses its pane, the next
--- waiting one on each call.
function mod.focusWaiting()
  local app = hs.application.get(mod.name)
  local layout = app and run('herdr-app ls')
  local status = layout and run('herdr-app status')
  local decoded = status and hs.json.decode(status) --[[@as HerdrStatus|nil]]
  local waiting = layout and mod.findWaiting(hs.json.decode(layout), decoded and decoded.focused_pane)
  if not app or not waiting then
    require('windows').launchOrCycleFocus(mod.name)()
    return
  end
  app:activate()
  run('herdr-app do pane.focus --pane ' .. waiting.pane)
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
--- then the others as listed. Terminals not running claude or copilot are left out.
---@param terminals HcTerminal[]
---@param last string|nil Address picked last.
---@param preferred string|nil
---@return HcTerminal[]
function mod.orderAgents(terminals, last, preferred)
  ---@type HcTerminal[]
  local agents = {}
  for _, terminal in ipairs(terminals) do
    if terminal.state == 'live' and isAgent({ terminal = terminal.address, app = terminal.agent }) then
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

--- Shows a picker prefilled with an `@` reference to what the focused window shows, the editor or Obsidian file and
--- selected lines, or the working directory of Herdr, iTerm2 and Finder, to type the rest of the prompt after it.
--- Other apps, e.g. Brave, add what their window shows, like its URL, and the selection as a quote after the prompt.
--- Each agent, the one picked last first, has a row pasting the prompt without Enter (the default) and one submitting it.
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
  local shown = mod.findAgent(layout and hs.json.decode(layout), mod.focusedAt)
  local listed = run('hc ls --json')
  local decoded = listed and hs.json.decode(listed)
  local agents =
    mod.orderAgents(decoded and decoded.terminals or {}, hs.settings.get(lastAgentKey), shown and shown.terminal)
  if #agents == 0 then
    hs.alert.show('Herdr: no claude or copilot running')
    return
  end

  ---@type table<string, string>
  local references = {}
  ---@type table[]
  local choices = {}
  local described = summaries()
  local attached = context and ('  ·  📎 ' .. context.title) or ''
  for _, agent in ipairs(agents) do
    local cwd = detailsCwd(terminalDetails(agent.address))
    local description = described[agent.address] or ''
    references[agent.address] = (file and path) and mod.reference(path, file.line, file.endLine, cwd) or ''
    local text = description ~= '' and description or string.format('%s %s', agent.agent, agent.address)
    local details = string.format(
      '%s %s  %s  %s  %s',
      agent.agent,
      agent.address,
      agent.status or '',
      agent.where or '',
      cwd or agent.cwd or ''
    )
    table.insert(choices, { text = text, subText = 'Paste  ·  ' .. details .. attached, address = agent.address })
    table.insert(
      choices,
      { text = text, subText = 'Submit ⏎  ·  ' .. details .. attached, address = agent.address, submit = true }
    )
  end
  local reference = references[agents[1].address]

  if chooser then
    chooser:delete()
  end
  chooser = hs.chooser.new(function(choice)
    local prompt = chooser and chooser:query() or ''
    if window and (not choice or choice.submit) then
      window:focus()
    end
    if not choice then
      return
    end
    for _, agent in ipairs(agents) do
      if agent.address == choice.address then
        hs.settings.set(lastAgentKey, agent.address)
        local rebased = path and mod.rebase(prompt, reference, references[agent.address])
          or mod.withContext(prompt, context, selected)
        if choice.submit then
          submit(agent, rebased)
        else
          paste(agent, rebased)
        end
        return
      end
    end
  end)
  chooser:bgDark(true)
  chooser:placeholderText('Prompt, ⏎ pastes into or submits to the highlighted agent')
  -- Typing writes the prompt, it does not filter the agents.
  chooser:queryChangedCallback(function() end)
  chooser:choices(choices)
  chooser:query(path and (reference .. ' ') or '')
  chooser:show()
end

return mod
