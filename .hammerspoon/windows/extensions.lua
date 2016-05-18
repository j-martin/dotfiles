-- initially from https://raw.githubusercontent.com/oskarols/dotfiles/0bd44443d00108e3c1a8d01520489e2d165f70ff/hammerspoon/extensions.lua

partial = hs.fnutils.partial
sequence = hs.fnutils.sequence

local fnutils = require "hs.fnutils"
local indexOf = fnutils.indexOf
local filter = fnutils.filter
local geometry = require "hs.geometry"
local mouse = require "hs.mouse"

local mod = {}

---------------------------------------------------------
-- functools
---------------------------------------------------------

local function isFunction(a)
  return type(a) == "function"
end

-- gets propery or method value
-- on a table
local function result(obj, property)
  if not obj then return nil end

  if isFunction(property) then
    return property(obj)
  elseif isFunction(obj[property]) then -- string
    return obj[property](obj) -- <- this will be the source of bugs
  else
    return obj[property]
  end
end

---------------------------------------------------------
-- Extension of native objects and modules
---------------------------------------------------------

function mod.centerOnRect(rect)
  mouse.setAbsolutePosition(geometry.rectMidPoint(rect))
end

---------------------------------------------------------
-- COORDINATES, POINTS, RECTS, FRAMES, TABLES
---------------------------------------------------------

-- Fetch next index but cycle back when at the end
--
-- > getNextIndex({1,2,3}, 3)
-- 1
-- > getNextIndex({1}, 1)
-- 1
-- @return int
local function getNextIndex(table, currentIndex)
  nextIndex = currentIndex + 1
  if nextIndex > #table then
    nextIndex = 1
  end

  return nextIndex
end

---------------------------------------------------------
-- MOUSE
---------------------------------------------------------

local mouseCircle = nil
local mouseCircleTimer = nil

function mod.mouseHighlight()
  -- Delete an existing highlight if it exists
  result(mouseCircle, "delete")
  result(mouseCircleTimer, "stop")

  -- Get the current co-ordinates of the mouse pointer
  local mousepoint = mouse.getAbsolutePosition()

  -- Prepare a big red circle around the mouse pointer
  mouseCircle = hs.drawing.circle(hs.geometry.rect(mousepoint.x-20, mousepoint.y-20, 40, 40))
  mouseCircle:setFillColor({["red"]=0.5,["blue"]=0.5,["green"]=0.5,["alpha"]=0.5})
  mouseCircle:setStrokeWidth(0)
  mouseCircle:show()

  -- Set a timer to delete the circle after 3 seconds
  mouseCircleTimer = hs.timer.doAfter(0.2, function()
    mouseCircle:delete()
  end)
end

---------------------------------------------------------
-- APPLICATION / WINDOW
---------------------------------------------------------

-- Returns the next successive window given a collection of windows
-- and a current selected window
--
-- @param  windows  list of hs.window or applicationName
-- @param  window   instance of hs.window
-- @return hs.window
local function getNextWindow(windows, window)
  if type(windows) == "string" then
    windows = hs.appfinder.appFromName(windows):allWindows()
  end

  windows = filter(windows, hs.window.isStandard)
  windows = filter(windows, hs.window.isVisible)

  -- need to sort by ID, since the default order of the window
  -- isn't usable when we change the mainWindow
  -- since mainWindow is always the first of the windows
  -- hence we would always get the window succeeding mainWindow
  table.sort(windows, function(w1, w2)
    return w1:id() > w2:id()
  end)

  lastIndex = indexOf(windows, window)

  return windows[getNextIndex(windows, lastIndex)]
end

-- Needed to enable cycling of application windows
local lastToggledApplication = ''

function mod.launchOrCycleFocus(applicationName)
  return function()
    local nextWindow = nil
    local targetWindow
    local focusedWindow = hs.window.focusedWindow()
    lastToggledApplication = focusedWindow and focusedWindow:application():title()

    if not focusedWindow then return nil end

    logger.df('last: %s, current: %s', lastToggledApplication, applicationName)

    if lastToggledApplication == applicationName then
      nextWindow = getNextWindow(applicationName, focusedWindow)
      nextWindow:becomeMain()
    else
      hs.application.launchOrFocus(applicationName)
    end

    if nextWindow then
      targetWindow = nextWindow
    else
      targetWindow = hs.window.focusedWindow()
    end

    if not targetWindow then
      logger.df('failed finding a window for application: %s', applicationName)
      return nil
    end

    local windowFrame = targetWindow:frame()
    mod.centerOnRect(windowFrame)
    mod.mouseHighlight()
  end
end

return mod
