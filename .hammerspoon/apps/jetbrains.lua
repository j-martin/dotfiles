local utils = require 'apps/utils'
local process = require 'utils/process'

-- Any IntelliJ based IDE, e.g. GoLand, IntelliJ IDEA, PyCharm or Android Studio.
---@class JetBrainsApp
---@field goland string
---@field idea string
---@field bundleIdPatterns string[]
---@field matches fun(bundleId: string|nil): boolean
---@field omni fun()
---@field navigationPath fun(root: string, components: string[], file: string, mode: fun(path: string): string|nil): string|nil
---@field titlePath fun(title: string, home: string, mode: fun(path: string): string|nil): string|nil
---@field context fun(window: hs.window): AppContext
local mod = {}

mod.goland = 'GoLand'
mod.idea = 'IntelliJ IDEA CE'

-- Lua patterns of the IntelliJ based IDE bundle IDs
mod.bundleIdPatterns = { '^com%.jetbrains%.', '^com%.google%.android%.studio' }

--- Returns whether the bundle ID is an IntelliJ based IDE.
---@param bundleId string|nil
---@return boolean
function mod.matches(bundleId)
  for _, pattern in ipairs(mod.bundleIdPatterns) do
    if bundleId and bundleId:match(pattern) then
      return true
    end
  end
  return false
end

--- Opens the class search of the frontmost IDE.
function mod.omni()
  hs.eventtap.keyStroke({ 'cmd' }, 'o')
end

---@param element hs.axuielement
---@return boolean
local function isEditor(element)
  local description = element:attributeValue('AXDescription')
  return element:attributeValue('AXRole') == 'AXTextArea'
    and type(description) == 'string'
    and description:match('^Editor for ') ~= nil
end

---@param element hs.axuielement
---@return boolean
local function isFocusedEditor(element)
  return isEditor(element) and element:attributeValue('AXFocused') == true
end

-- The focused element of the IDE is sometimes an invalid reference, or not focused when the window is not, so search
-- the window as a fallback
---@param window hs.window
---@param windowElement hs.axuielement
---@return hs.axuielement|nil
local function findEditor(window, windowElement)
  local focused = hs.axuielement.applicationElement(window:application()):attributeValue('AXFocusedUIElement')
  if focused and isFocusedEditor(focused) then
    return focused
  end
  return utils.findElement(windowElement, isFocusedEditor, 8) or utils.findElement(windowElement, isEditor, 8)
end

-- The project widget of the toolbar has the project directory as its tooltip, e.g. "~/src/project"
---@param element hs.axuielement
---@return boolean
local function isProjectWidget(element)
  local help = element:attributeValue('AXRole') == 'AXButton' and element:attributeValue('AXHelp')
  return type(help) == 'string' and help:match('^[~/]') ~= nil
end

---@param windowElement hs.axuielement
---@return string|nil
local function projectRoot(windowElement)
  local widget = utils.findElement(windowElement, isProjectWidget, 6)
  return widget and (widget:attributeValue('AXHelp'):gsub('^~', os.getenv('HOME')))
end

---@param element hs.axuielement
---@return boolean
local function isNavigationBar(element)
  return element:attributeValue('AXRole') == 'AXGroup' and element:attributeValue('AXDescription') == 'Navigation Bar'
end

-- The navigation bar of the status bar lists the project folder name, the folders and the file, then its symbols
---@param windowElement hs.axuielement
---@return string[]
local function navigationBar(windowElement)
  local bar = utils.findElement(windowElement, isNavigationBar, 8)
  ---@type string[]
  local components = {}
  for _, child in ipairs(bar and bar:attributeValue('AXChildren') or {}) do
    table.insert(components, child:attributeValue('AXDescription') or '')
  end
  return components
end

--- Returns the file path from the navigation bar components, when they start with the project folder name. The bar
--- sometimes shows the symbol instead of the file, so it follows the existing folders, then looks for the file there.
---@param root string
---@param components string[]
---@param file string
---@param mode fun(path: string): string|nil Returns `directory` or `file`, nil when missing.
---@return string|nil
function mod.navigationPath(root, components, file, mode)
  local parent, name = root:gsub('/$', ''):match('^(.*)/([^/]+)$')
  if not name or components[1] ~= name then
    return nil
  end
  local path = parent
  for _, component in ipairs(components) do
    local candidate = path .. '/' .. component
    if component == file and mode(candidate) == 'file' then
      return candidate
    end
    if mode(candidate) ~= 'directory' then
      break
    end
    path = candidate
  end
  return mode(path .. '/' .. file) == 'file' and path .. '/' .. file or nil
end

--- Returns the file of the window title, `<project> – <file>`, when it is a path: the title shows the full path of
--- files outside the project, e.g. `infra – ~/src/other/main.go`.
---@param title string
---@param home string
---@param mode fun(path: string): string|nil Returns `directory` or `file`, nil when missing.
---@return string|nil
function mod.titlePath(title, home, mode)
  local file = title:match('^.-%s+–%s+(.+)$')
  if not file or not file:match('^[~/]') then
    return nil
  end
  local path = file:gsub('^~', home)
  return mode(path) == 'file' and path or nil
end

---@param path string
---@return string|nil
local function fileMode(path)
  return hs.fs.attributes(path, 'mode') --[[@as string|nil]]
end

---@param root string
---@param args string
---@return string|nil
local function git(root, args)
  local output, ok = process.execute('git -C ' .. string.format('%q', root) .. ' ' .. args .. ' 2>/dev/null')
  return ok and output or nil
end

-- The editor only exposes the file name, so look for it in the project
---@param root string
---@param file string
---@return string|nil
local function gitPath(root, file)
  if hs.fs.attributes(root .. '/' .. file) then
    return root .. '/' .. file
  end
  local matches = {}
  for match in (git(root, 'ls-files --full-name -- ' .. string.format('%q', '*/' .. file)) or ''):gmatch('[^\n]+') do
    table.insert(matches, match)
  end
  if #matches ~= 1 then
    return nil
  end
  return git(root, 'rev-parse --show-toplevel'):gsub('%s+$', '') .. '/' .. matches[1]
end

-- 1-based first and last lines of the selection, the caret line without one
---@param editor hs.axuielement
---@return integer|nil
---@return integer|nil
local function selectedLines(editor)
  local range = editor:attributeValue('AXSelectedTextRange')
  if not range then
    local line = editor:attributeValue('AXInsertionPointLineNumber')
    return line and line + 1, line and line + 1
  end
  local first = editor:parameterizedAttributeValue('AXLineForIndex', range.location)
  -- The last selected character, so a selection ending with a line break stays on its line
  local last = editor:parameterizedAttributeValue('AXLineForIndex', range.location + math.max(range.length - 1, 0))
  return first and first + 1, (last or first) and (last or first) + 1
end

--- Returns the current file, its path and selected lines, project, and selected text.
---@param window hs.window
---@return AppContext
function mod.context(window)
  local project, file = window:title():match('^(.-)%s+–%s+(.+)$')
  local windowElement = hs.axuielement.windowElement(window)
  local editor = findEditor(window, windowElement)
  file = editor and editor:attributeValue('AXDescription'):match('^Editor for (.+)$') or file
  if not file then
    return { title = window:title() }
  end
  local root = projectRoot(windowElement)
  local path = mod.titlePath(window:title(), os.getenv('HOME') or '', fileMode)
    or root and (mod.navigationPath(root, navigationBar(windowElement), file, fileMode) or gitPath(root, file))
  local line, endLine
  if editor then
    line, endLine = selectedLines(editor)
  end
  local location = path or file
  return {
    title = file,
    url = line and (location .. ':' .. line) or location,
    path = path,
    line = line,
    endLine = endLine,
    details = { window:application():name() .. ' project: ' .. (root or project or '?') },
    selection = editor and editor:attributeValue('AXSelectedText') or nil,
  }
end

return mod
