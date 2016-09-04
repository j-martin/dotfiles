local window = require "hs.window"
local grid = require "hs.grid"
local layout = require "hs.layout"
local screen = require "hs.screen"
local fnutils = require "hs.fnutils"
local geometry = require "hs.geometry"
local logger = hs.logger.new('windows', 'info')

local ext = require "windows/extensions"

local mod = {}

mod.launchOrCycleFocus = ext.launchOrCycleFocus

-- grid/window settings
grid.ui.textSize = 15
grid.GRIDWIDTH = 10
grid.GRIDHEIGHT = 4
grid.MARGINX = 0
grid.MARGINY = 0
window.animationDuration = 0

local center40 = geometry.unitrect(0.3, 0, 0.4, 1)

function mod.applyLayout(commonLayout, selectedLayout)
  local function expandLayout(entry)
    local scr
    if entry.screenFn then
      scr = entry.screenFn()
    else
      scr = screen.primaryScreen():name()
    end
    return { entry.name, nil, scr, entry.pos, nil, nil }
  end

  return function()
    local completeLayout = fnutils.map(fnutils.concat(selectedLayout, commonLayout), expandLayout)
    layout.apply(completeLayout)
  end
end

function mod.center40()
  window.focusedWindow():move(center40)
end

function mod.maximize()
  window.focusedWindow():maximize()
end

local function centerCursor()
  ext.centerOnRect(window.focusedWindow():frame())
  ext.mouseHighlight()
end

-- required for reseting the previous state.
local cycleStates = {}

-- cycles window size
local function cycleWidth(startPoint)
  local width
  local focusedWindow = window.frontmostWindow()
  focusedWindow:focus()

  local focusedApplication = focusedWindow:application():name()
  local primaryScreen = screen.primaryScreen():currentMode()
  local currentWidth = focusedWindow:frame().w / primaryScreen.w
  local isDifferentStartPoint = cycleStates[focusedApplication] ~= startPoint

  if currentWidth < 0.31 or currentWidth > 0.9 or isDifferentStartPoint then
    width = 0.5
  elseif currentWidth < 0.51 then
    width = 0.7
  else
    width = 0.3
  end

  cycleStates[focusedApplication] = startPoint
  local xPos = startPoint * (1 - (startPoint * width))
  focusedWindow:move({xPos, 0, width, 1})
  ext.centerOnWindow()
end

function mod.cycleLeft()
  cycleWidth(0)
end

function mod.cycleRight()
  cycleWidth(1)
end

function mod.snapAll()
  fnutils.each(window.visibleWindows(), grid.snap)
end

function mod.moveTo(pos)
  return function()
    window.focusedWindow():move(pos)
    ext.centerOnWindow()
  end
end

local function maximizeOrCycleScreen()
  local win = window.focusedWindow()
  if win:frame().w + 10 <= win:screen():frame().w then
    win:maximize()
    return win, nil
  else
    return win, win:screen()
  end
end

function mod.cycleScreen()
  local win, currentScreen = maximizeOrCycleScreen()
  if currentScreen then
    win:moveToScreen(currentScreen:next())
  end
  ext.centerOnWindow()
end

function mod.cycleScreenBack()
  local win, currentScreen = maximizeOrCycleScreen()
  if currentScreen then
    win:moveToScreen(currentScreen:previous())
  end
  ext.centerOnWindow()
end

 function mod.alternateScreen()
  local laptopScreen = 'Color LCD'
  local extraScreen = 'SMS24A850'
  if screen.find(extraScreen) then
    return extraScreen
  else
    return laptopScreen
  end
end

return mod
