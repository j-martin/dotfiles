local utils = require 'apps/utils'

---@class GoLandApp
---@field name string
---@field context fun(window: hs.window): table<string, any>|nil
local mod = {}

mod.name = 'GoLand'

---@param element hs.axuielement
---@return boolean
local function isFocusedEditor(element)
  local description = element:attributeValue('AXDescription')
  return element:attributeValue('AXRole') == 'AXTextArea'
    and element:attributeValue('AXFocused') == true
    and type(description) == 'string'
    and description:match('^Editor for ') ~= nil
end

-- The focused element of GoLand is sometimes an invalid reference, so search the window as a fallback
---@param window hs.window
---@param windowElement hs.axuielement
---@return hs.axuielement|nil
local function focusedEditor(window, windowElement)
  local focused = hs.axuielement.applicationElement(window:application()):attributeValue('AXFocusedUIElement')
  if focused and isFocusedEditor(focused) then
    return focused
  end
  return utils.findElement(windowElement, isFocusedEditor, 8)
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

---@param root string
---@param args string
---@return string|nil
local function git(root, args)
  local output, ok = hs.execute('git -C ' .. string.format('%q', root) .. ' ' .. args .. ' 2>/dev/null')
  return ok and output or nil
end

-- GoLand only exposes the file name, so look for it in the project
---@param root string
---@param file string
---@return string|nil
local function filePath(root, file)
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

--- Returns the current file, its path and line, project, and selected text.
---@param window hs.window
---@return table<string, any>
function mod.context(window)
  local project, file = window:title():match('^(.-)%s+–%s+(.+)$')
  local windowElement = hs.axuielement.windowElement(window)
  local editor = focusedEditor(window, windowElement)
  file = editor and editor:attributeValue('AXDescription'):match('^Editor for (.+)$') or file
  if not file then
    return { title = window:title() }
  end
  local root = projectRoot(windowElement)
  local path = root and filePath(root, file) or file
  local line = editor and editor:attributeValue('AXInsertionPointLineNumber')
  return {
    title = file,
    url = line and (path .. ':' .. (line + 1)) or path,
    details = { 'GoLand project: ' .. (root or project or '?') },
    selection = editor and editor:attributeValue('AXSelectedText') or nil,
  }
end

return mod
