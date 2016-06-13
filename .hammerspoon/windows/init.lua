local window = require "hs.window"
local grid = require "hs.grid"
local chooser = require "hs.chooser"
local layout = require "hs.layout"
local screen = require "hs.screen"
local fnutils = require "hs.fnutils"
local geometry = require "hs.geometry"
local alert = require "hs.alert"

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

local laptopScreen = "Color LCD"

local commonLayout = {
  {"Inbox",  nil, laptopScreen, layout.left70, nil, nil},
  {"Slack",  nil, laptopScreen, layout.right50, nil, nil},
}

local center40 = geometry.unitrect(0.3, 0, 0.4, 1)

-- displays layout chooser
function mod.pickLayout(layoutChoices)
  return function()
    chooser.new(function(chosenLayout)
        local primaryScreen = screen.primaryScreen():name()
        local expandLayout = fnutils.map(chosenLayout.layout, function (entry)
          return {entry[1], nil, primaryScreen, entry[2], nil, nil}
        end)
        local fullLayout = fnutils.concat(commonLayout, expandLayout)
        layout.apply(fullLayout)
    end):choices(layoutChoices):show()
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
  local fWindow = window.focusedWindow()
  local fApplication = fWindow:application():name()
  local primaryScreen = screen.primaryScreen():currentMode()
  local currentWidth = fWindow:frame().w / primaryScreen.w
  local isDifferentStartPoint = cycleStates[fApplication] ~= startPoint

  if currentWidth < 0.31 or currentWidth > 0.9 or isDifferentStartPoint then
    width = 0.5
  elseif currentWidth < 0.51 then
    width = 0.7
  else
    width = 0.3
  end

  cycleStates[fApplication] = startPoint
  local xPos = startPoint * (1 - (startPoint * width))
  fWindow:move({xPos, 0, width, 1})
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

function mod.modalLayout(modal, mLayouts)
  function modal:entered()
    alert.show('Modal Layout', 120)
  end

  function modal:exited()
    alert.closeAll()
    alert.show('Exited mode')
  end

  local function exit() modal:exit() end

  local function applyLayout(selectedLayout)

    local function moveTo()
      window.focusedWindow():move(selectedLayout.pos)
    end

    local function moveToAndExit()
        moveTo()
        exit()
    end

    modal:bind({}, selectedLayout.key, moveTo)
    modal:bind({'shift'}, selectedLayout.key, moveToAndExit)
  end

  modal:bind({}, 'escape', exit)
  modal:bind({}, 'space', exit)
  modal:bind({}, 'tab', window.switcher.previousWindow)
  modal:bind({'shift'}, 'tab', window.switcher.nextWindow)

  fnutils.each(mLayouts, applyLayout)
end

return mod
