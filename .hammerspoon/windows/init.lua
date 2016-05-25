local window = require "hs.window"
local grid = require "hs.grid"
local chooser = require "hs.chooser"
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
  {"Inbox",  nil, laptopScreen, layout.left70, nil, nil},
  {"Slack",  nil, laptopScreen, layout.right50, nil, nil},
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
      local primaryScreen = screen.primaryScreen():name()
      local expandLayout = fnutils.map(chosenLayout.layout, function (entry)
        return {entry[1], nil, primaryScreen, entry[2], nil, nil}
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

local function centerCursor()
  ext.centerOnRect(window.focusedWindow():frame())
  ext.mouseHighlight()
end

-- required for reseting the previous state.
local previousCycleStartPoint = 0

-- cycles window size
function mod.cycleWidth(startPoint)
  local width = nil
  local fWindow = window.focusedWindow()
  local primaryScreen = screen.primaryScreen():currentMode()
  local currentWidth = fWindow:frame().w / primaryScreen.w

  if previousCycleStartPoint ~= startPoint then
    width = 0.5
  elseif currentWidth < 0.31 then
    width = 0.5
  elseif currentWidth < 0.51 then
    width = 0.7
  else
    width = 0.3
  end

  previousCycleStartPoint = startPoint
  local x = startPoint * (1 - (startPoint * width))
  local frame = geometry.unitrect(x, 0, width, 1)
  fWindow:move(frame)
  ext.centerOnWindow()
end

return mod
