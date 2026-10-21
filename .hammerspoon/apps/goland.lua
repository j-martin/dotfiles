local utils = require 'apps/utils'

local mod = {}

mod.name = 'GoLand'

local function isFocusedEditor(element)
  local description = element:attributeValue('AXDescription')
  return element:attributeValue('AXRole') == 'AXTextArea'
    and element:attributeValue('AXFocused') == true
    and type(description) == 'string'
    and description:match('^Editor for ') ~= nil
end

-- The focused element of GoLand is sometimes an invalid reference, so search the window as a fallback
local function focusedEditor(window, windowElement)
  local focused = hs.axuielement.applicationElement(window:application()):attributeValue('AXFocusedUIElement')
  if focused and isFocusedEditor(focused) then
    return focused
  end
  return utils.findElement(windowElement, isFocusedEditor, 8)
end

-- The project widget of the toolbar has the project directory as its tooltip, e.g. "~/src/project"
local function isProjectWidget(element)
  local help = element:attributeValue('AXRole') == 'AXButton' and element:attributeValue('AXHelp')
  return type(help) == 'string' and help:match('^[~/]') ~= nil
end

local function projectRoot(windowElement)
  local widget = utils.findElement(windowElement, isProjectWidget, 6)
  return widget and (widget:attributeValue('AXHelp'):gsub('^~', os.getenv('HOME')))
end

local function git(root, args)
  local output, ok = hs.execute('git -C ' .. string.format('%q', root) .. ' ' .. args .. ' 2>/dev/null')
  return ok and output or nil
end

-- GoLand only exposes the file name, so look for it in the project
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
function mod.context(window)
  -- e.g. "project – file.go"
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
    -- The line number is 0-based
    url = line and (path .. ':' .. (line + 1)) or path,
    details = { 'GoLand project: ' .. (root or project or '?') },
    selection = editor and editor:attributeValue('AXSelectedText') or nil,
  }
end

return mod
