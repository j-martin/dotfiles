local window = require "hs.window"
local grid = require "hs.grid"
local layout = require "hs.layout"
local screen = require "hs.screen"
local fnutils = require "hs.fnutils"
local timer = require "hs.timer"
local geometry = require "hs.geometry"
local logger = hs.logger.new('windows', 'debug')

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

function mod.grid()
  grid.setGrid('10x4')
  grid.show()
end

function mod.altGrid()
  grid.setGrid('8x4')
  grid.show()
end

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
    ext.centerOnWindow()
  end
end

local previousStates = {}

function mod.moveToPrimaryScreen(pos)
  local function round(value)
    return math.ceil(value * 10) / 10
  end

  local function buildKey(win)
    return table.concat(pos,'\0') .. win:id()
  end

  local function toUnitRect(win)
    local unitRect = fnutils.map(win:screen():toUnitRect(win:frame()), round)
    return { unitRect._x, unitRect._y, unitRect._w, unitRect._h }
  end

  local function isSamePos(previousPos)
    return
      pos[0] == previousPos[0] and
      pos[1] == previousPos[1] and
      pos[2] == previousPos[2] and
      pos[3] == previousPos[3]
  end

  return function()
    local win = window:focusedWindow()
    local winKey = buildKey(win)
    local winPos = toUnitRect(win)
    local previousState = previousStates[winKey]

    if previousState and isSamePos(winPos) then
      win:move(previousState.pos, previousState.screen)
      previousStates[winKey] = nil
      logger.d('reverted to previousState')
    else
      previousStates[winKey] = { screen = win:screen(), pos = winPos }
      win:move(pos, screen.primaryScreen())
      logger.d('saved previousState')
    end
    ext.centerOnTitle(win:frame())
  end
end

function mod.maximize()
  window.focusedWindow():maximize()
end

local function isTableOfTables(t)
  for _, v in ipairs(t) do
    if type(v) ~= 'table' then
      return false
    end
  end
  return true
end

-- required for reseting the previous state.
local cycleStates = {}

-- cycles window size
function mod.setPosition(pos)
  if not isTableOfTables(pos) then
    return mod.moveToPrimaryScreen(pos)
  end
  local nextPos
  return function()
    local win = window.frontmostWindow():focus()
    local id = win:id()

    if cycleStates[id] ~= pos then
      nextPos = fnutils.cycle(pos)
    end

    cycleStates[id] = pos
    win:move(nextPos(), screen.primaryScreen())
    ext.centerOnTitle(win:frame())
  end
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

function mod.previousScreen()
  local win = window.focusedWindow()
  win:moveToScreen(win:screen():previous())
end

function mod.nextScreen()
  local win = window.focusedWindow()
  win:moveToScreen(win:screen():next())
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
