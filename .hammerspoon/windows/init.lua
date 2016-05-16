local window = require "hs.window"
local grid = require "hs.grid"
local chooser = require "hs.chooser"
local mouse = require "hs.mouse"
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
grid.GRIDHEIGHT = 3
grid.MARGINX = 0
grid.MARGINY = 0
window.animationDuration = 0

local laptopScreen = "Color LCD"

local commonLayout = {
  {"Slack",  nil, laptopScreen, layout.right50, nil, nil},
  {"Inbox",  nil, laptopScreen, layout.left50, nil, nil},
}

local center40 = geometry.unitrect(0.3, 0, 0.4, 1)

local layoutChoices = {
  {
    text = "50/50",
    subText = "50/50",
    layout = {
      {"Emacs", layout.left50},
      {"iTerm2", layout.right50},
      {"Google Chrome", layout.right50},
      {"IntelliJ IDEA", layout.right50},
      {"Sublime Text", layout.right50},
    }
  },
  { text = "70/30",
    subText = "70/30",
    layout = {
      {"Emacs", layout.left70},
      {"IntelliJ IDEA", layout.right70},
      {"Google Chrome", layout.right30},
      {"iTerm2", layout.right30},
    }
  },
  {
    text = "30/70",
    subText = "30/70",
    layout = {
      {"Emacs", layout.left30},
      {"Google Chrome", layout.right70},
      {"IntelliJ IDEA", layout.right70},
      {"iTerm2", layout.right70},
    }
  },
}

-- displays layout chooser
function mod.pickLayout()
  chooser.new(function(chosenLayout)
      local mainScreen = screen.mainScreen():name()
      local expandLayout = fnutils.map(chosenLayout.layout, function (entry)
        return {entry[1], nil, mainScreen, entry[2], nil, nil}
      end)
      local fullLayout = fnutils.concat(commonLayout, expandLayout)
      layout.apply(fullLayout)
  end):choices(layoutChoices):show()
end

function mod.center40()
  window.focusedWindow():move(center40)
end

function mod.maximize()
  window.focusedWindow():maximize()
end

function centerCursor()
  mouse.centerOnRect(window.focusedWindow():frame())
  mouseHighlight()
end

-- required for reseting the previous state.
local previousCycleStartPoint = 0

-- cycles window size
function mod.cycleWidth(startPoint)
  local focusedWindow = hs.window.focusedWindow()
  local mainScreen = screen.mainScreen():currentMode()

  local divisor = nil
  local currentRatio = mainScreen.w / focusedWindow:frame().w
  if previousCycleStartPoint ~= startPoint then
    divisor = 2
  elseif currentRatio < 1.7 then
    divisor = 2.65
  elseif currentRatio < 2.1 then
    divisor = 1.61
  else
    divisor = 2
  end

  local w = mainScreen.w/divisor
  local x = (mainScreen.w - w) * startPoint
  focusedWindow:setFrame({x, 0, w, mainScreen.h})
  previousCycleStartPoint = startPoint
  centerCursor()
end

return mod
