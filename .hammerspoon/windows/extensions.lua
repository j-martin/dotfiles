-- initially from https://raw.githubusercontent.com/oskarols/dotfiles/0bd44443d00108e3c1a8d01520489e2d165f70ff/hammerspoon/extensions.lua

local logger = hs.logger.new('windows.ext', 'debug')

---@class WindowsExtensionModule
---@field mouseHighlight fun()
---@field centerOnTitle fun(rect: table): nil
---@field launchOrCycleFocus fun(applicationName: string): fun()
local mod = {}

hs.application.enableSpotlightForNameSearches(true)
---------------------------------------------------------
-- functools
---------------------------------------------------------

---@param a any
---@return boolean
local function isFunction(a)
  return type(a) == 'function'
end

-- gets property or method value
-- on a table
---@param obj table|nil
---@param property any
---@return any
local function result(obj, property)
  if not obj then
    return nil
  end

  if isFunction(property) then
    return property(obj)
  elseif isFunction(obj[property]) then
    return obj[property](obj)
  else
    return obj[property]
  end
end

---------------------------------------------------------
-- Coordinates, points, rects, frames, tables
---------------------------------------------------------

-- Fetch next index but cycle back when at the end
--
-- > getNextIndex({1,2,3}, 3)
-- 1
-- > getNextIndex({1}, 1)
-- 1
-- @return int
---@param tableValue table
---@param currentIndex number
---@return number
local function getNextIndex(tableValue, currentIndex)
  local nextIndex = currentIndex + 1
  if nextIndex > #tableValue then
    nextIndex = 1
  end

  return nextIndex
end

---------------------------------------------------------
-- Mouse
---------------------------------------------------------

local mouseCircle = nil
local mouseCircleTimer = nil

function mod.mouseHighlight()
  result(mouseCircle, 'delete')
  result(mouseCircleTimer, 'stop')

  local mousePoint = hs.mouse.getAbsolutePosition()

  local radius = 100

  local circle = hs.geometry.rect(mousePoint.x - (radius / 2), mousePoint.y - (radius / 2), radius, radius)

  local fillColor = { red = 0.5, blue = 0.5, green = 0.5, alpha = 1 }

  mouseCircle = hs.drawing.circle(circle)
  mouseCircle:setFillColor(fillColor)
  mouseCircle:show()

  mouseCircleTimer = hs.timer.doAfter(0.07, function()
    mouseCircle:delete()
  end)
end

---@param rect table
function mod.centerOnTitle(rect)
  local point = hs.geometry.point(rect.x + rect.w / 5, rect.y + rect.h / 5)
  hs.mouse.absolutePosition(point)
end

---------------------------------------------------------
-- Application / window
---------------------------------------------------------

-- Returns the next successive window given a collection of windows
-- and a current selected window
--
-- @param  windows  list of hs.window or applicationName
-- @param  window   instance of hs.window
-- @return hs.window
---@param currentWindow hs.window
---@return hs.window|nil
local function getNextWindow(currentWindow)
  local windows = currentWindow:application():allWindows()

  local function filterStd(win)
    return win:isStandard()
  end

  windows = hs.fnutils.filter(windows, filterStd)

  table.sort(windows, function(w1, w2)
    return w1:id() > w2:id()
  end)

  local lastIndex = hs.fnutils.indexOf(windows, currentWindow)
  return windows[getNextIndex(windows, lastIndex)]
end

local lastToggledAppName = ''

local cursorPositions = {}

---@param applicationName string
---@return fun()
function mod.launchOrCycleFocus(applicationName)
  local function cleanupName(name)
    return name:gsub('.app$', '')
  end

  return function()
    local nextWindow = nil
    local targetWindow
    local focusedWindow = hs.window.frontmostWindow()
    if focusedWindow then
      cursorPositions[focusedWindow:title()] = hs.mouse.absolutePosition()
    end
    if not focusedWindow then
      hs.application.launchOrFocus(applicationName:gsub('[0-9]+', ''))
      return
    end
    local app = focusedWindow:application()

    focusedWindow:focus()
    local currentAppName
    if app:path() then
      currentAppName = cleanupName(focusedWindow and hs.fs.displayName(app:path()))
    end
    lastToggledAppName = currentAppName

    local appName = cleanupName(applicationName)
    logger.df('last: %s, current: %s', currentAppName, appName)
    if currentAppName == appName:gsub('[0-9]+', '') then
      nextWindow = getNextWindow(focusedWindow)
      if nextWindow then
        nextWindow:becomeMain()
      end
    else
      logger.df('launch or focus %s', app)
      if not hs.application.launchOrFocus(applicationName) then
        local sanitizedName = applicationName:gsub('[0-9]+', '')
        hs.application.launchOrFocus(sanitizedName)
      end
    end

    if nextWindow then
      targetWindow = nextWindow
    else
      targetWindow = hs.window.focusedWindow()
    end

    if not targetWindow then
      logger.df('failed finding a window for application: %s', applicationName)
      return
    end

    local previousCursorPosition = cursorPositions[targetWindow:title()]
    if previousCursorPosition then
      hs.mouse.absolutePosition(previousCursorPosition)
    else
      if applicationName == 'iTerm2' then
        hs.mouse.absolutePosition(hs.geometry.point(hs.screen.mainScreen():fullFrame().w / 2, 5))
      else
        mod.centerOnTitle(targetWindow:frame())
      end
    end
    if applicationName == 'GoLand' then
      local windowTitle = targetWindow:title()
      print('Forefront window title: ' .. windowTitle)
      if windowTitle == 'File Cache Conflict' then
        hs.eventtap.keyStroke({ 'alt' }, 'l')
      end
    end
  end
end

return mod
