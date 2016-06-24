local window = require "hs.window"
local grid = require "hs.grid"
local layout = require "hs.layout"
local screen = require "hs.screen"
local fnutils = require "hs.fnutils"
local geometry = require "hs.geometry"

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
    local primaryScreen = screen.primaryScreen():name()
    return {entry[1], nil, primaryScreen, entry[2], nil, nil}
  end

  return function()
    local expandedLayout = fnutils.map(selectedLayout, expandLayout)
    local completeLayout = fnutils.concat(commonLayout, expandedLayout)
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
  local width = nil
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

function mod.cycleScreen()
  local nextScreen = window.focusedWindow():screen():next()
  window.focusedWindow():moveToScreen(nextScreen)
  ext.centerOnWindow()
end

function mod.cycleScreenBack()
  local nextScreen = window.focusedWindow():screen():previous()
  window.focusedWindow():moveToScreen(nextScreen)
  ext.centerOnWindow()
end

return mod
