-- initially from https://raw.githubusercontent.com/oskarols/dotfiles/0bd44443d00108e3c1a8d01520489e2d165f70ff/hammerspoon/extensions.lua

local logger = hs.logger.new('windows.ext', 'debug')

local mod = {}

hs.application.enableSpotlightForNameSearches(true)
---------------------------------------------------------
-- functools
---------------------------------------------------------

local function isFunction(a)
  return type(a) == "function"
end

-- gets propery or method value
-- on a table
local function result(obj, property)
  if not obj then
    return nil
  end

  if isFunction(property) then
    return property(obj)
  elseif isFunction(obj[property]) then -- string
    return obj[property](obj) -- <- this will be the source of bugs
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
local function getNextIndex(table, currentIndex)
  local nextIndex = currentIndex + 1
  if nextIndex > #table then
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
  -- Delete an existing highlight if it exists
  result(mouseCircle, "delete")
  result(mouseCircleTimer, "stop")

  -- Get the current co-ordinates of the mouse pointer
  local mousepoint = hs.mouse.getAbsolutePosition()

  local circle = hs.geometry.rect(mousepoint.x - 20, mousepoint.y - 20, 40, 40)

  local fillColor = {red = 0.5, blue = 0.5, green = 0.5, alpha = 0.5}

  mouseCircle = hs.drawing.circle(circle)
  mouseCircle:setFillColor(fillColor)
  mouseCircle:setStrokeWidth(0)
  mouseCircle:show()

  -- Set a hs.timer to delete the circle after 3 seconds
  mouseCircleTimer = hs.timer.doAfter(0.2, function()
    mouseCircle:delete()
  end)
end

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
local function getNextWindow(currentWindow)
  local windows = currentWindow:application():allWindows()

  local function filterStd(win)
    return win:isStandard()
  end

  windows = hs.fnutils.filter(windows, filterStd)
  -- windows = hs.fnutils.filter(windows, hs.window.isVisible)

  -- need to sort by ID, since the default order of the window
  -- isn't usable when we change the mainWindow
  -- since mainWindow is always the first of the windows
  -- hence we would always get the window succeeding mainWindow
  table.sort(windows, function(w1, w2)
    return w1:id() > w2:id()
  end)

  local lastIndex = hs.fnutils.indexOf(windows, currentWindow)
  return windows[getNextIndex(windows, lastIndex)]
end

-- Needed to enable cycling of application windows
local lastToggledAppName = ''

function mod.launchOrCycleFocus(applicationName)
  local function cleanupName(name)
    return name:gsub('.app$', '')
  end

  return function()
    local nextWindow = nil
    local targetWindow
    local focusedWindow = hs.window.frontmostWindow()
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

    if applicationName == 'iTerm2' then
      -- moving the cursor out the window, to preserve iTerm currently focused split
      hs.mouse.absolutePosition(hs.geometry.point(hs.screen.mainScreen():fullFrame().w / 2, 5))
    end

    local appName = cleanupName(applicationName)
    logger.df('last: %s, current: %s', currentAppName, appName)
    if currentAppName == appName:gsub('[0-9]+', '') then
      nextWindow = getNextWindow(focusedWindow)
      nextWindow:becomeMain()
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
      return nil
    end

    mod.centerOnTitle(targetWindow:frame())
  end
end

return mod
