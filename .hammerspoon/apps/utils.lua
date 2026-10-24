local logger = hs.logger.new('apps', 'info')
local windows = require 'windows'

local mod = {}

--- Returns the full path of an executable installed by Homebrew or in ~/bin, or its name if not found.
---@param exec string
---@return string
function mod.getExecPath(exec)
  local dirs = { '/opt/homebrew/bin/', '/usr/local/bin/', os.getenv('HOME') .. '/bin/' }
  for _, dir in ipairs(dirs) do
    local path = dir .. exec
    if hs.fs.attributes(path) then
      return path
    end
  end
  logger.i("Could not find executable in PATHs. Defaulting to executable's name.")
  return exec
end

--- Waits n hundredths of a second.
---@param n number|nil
function mod.wait(n)
  hs.timer.usleep(10000 * (n or 1))
end

--- Focuses the application, then sends it a key stroke.
---@param application string
---@param modifiers table
---@param keyStroke string
---@param delay number|nil
function mod.switchToAndType(application, modifiers, keyStroke, delay)
  windows.launchOrCycleFocus(application)()
  mod.wait(delay)
  hs.eventtap.keyStroke(modifiers, keyStroke)
end

--- Opens the URL with the application of the bundle id.
---@param bundleId string
---@param url string
function mod.open(bundleId, url)
  logger.i(bundleId, url)

  hs.application.launchOrFocusByBundleID(bundleId)
  hs.urlevent.openURLWithBundle(url, bundleId)
end

--- Returns the first accessibility element, depth first, for which `predicate` returns true.
---@param element hs.axuielement
---@param predicate fun(element: hs.axuielement): boolean
---@param depth number
---@return hs.axuielement|nil
function mod.findElement(element, predicate, depth)
  if not element then
    return nil
  end
  if predicate(element) then
    return element
  end
  if depth <= 0 then
    return nil
  end
  for _, child in ipairs(element:attributeValue('AXChildren') or {}) do
    local found = mod.findElement(child, predicate, depth - 1)
    if found then
      return found
    end
  end
  return nil
end

--- Returns a predicate matching accessibility elements with the given role.
---@param role string
---@return fun(element: hs.axuielement): boolean
function mod.hasRole(role)
  return function(element)
    return element and element:attributeValue('AXRole') == role
  end
end

--- Electron and Chromium apps only expose their web page accessibility tree once asked to.
---@param app hs.application
function mod.enableManualAccessibility(app)
  if app then
    hs.axuielement.applicationElement(app):setAttributeValue('AXManualAccessibility', true)
  end
end

return mod
