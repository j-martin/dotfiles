local ext = require "windows/extensions"
local logger = hs.logger.new('windows', 'debug')

local mod = {}

mod.launchOrCycleFocus = ext.launchOrCycleFocus

-- grid/window settings
hs.grid.ui.textSize = 15
hs.grid.GRIDWIDTH = 10
hs.grid.GRIDHEIGHT = 4
hs.grid.MARGINX = 0
hs.grid.MARGINY = 0
hs.window.animationDuration = 0
hs.window.timeout(1)

function mod.isUltraWide(win)
  local frame = win:screen():frame()
  return frame.w / frame.h > 2
end

function mod.applyLayout(commonLayout, selectedLayout)
  local function expandLayout(entry)
    local scr
    if entry.screenFn then
      scr = entry.screenFn()
    else
      scr = hs.screen.primaryScreen():name()
    end
    return {entry.name, nil, scr, entry.pos, nil, nil}
  end

  return function()
    local completeLayout = hs.fnutils.map(hs.fnutils.concat(selectedLayout, commonLayout), expandLayout)
    hs.layout.apply(completeLayout)
  end
end

local function toUnitRect(win)
  local function round(value)
    return math.ceil(value * 10) / 10
  end

  local unitRect = hs.fnutils.map(win:screen():toUnitRect(win:frame()), round)
  return {unitRect._x, unitRect._y, unitRect._w, unitRect._h}
end

local function isSamePos(currentPos, previousPos)
  return currentPos[0] == previousPos[0] and currentPos[1] == previousPos[1] and currentPos[2] == previousPos[2]
           and currentPos[3] == previousPos[3]
end

local function inPostions(currentPos, positions)
  for _, p in ipairs(positions) do
    if isSamePos(currentPos, p) then
      return true
    end
  end
  return false
end

local previousStates = {}

function mod.moveWindowTo(position, positionsUltraWide)
  local function buildKey(win)
    return table.concat(position, '\0') .. win:id()
  end

  return function()
    local win = hs.window:frontmostWindow()
    local winKey = buildKey(win)
    local winPos = toUnitRect(win)
    local previousState = previousStates[winKey]

    local _position = position
    if mod.isUltraWide(win) and positionsUltraWide then
      _position = positionsUltraWide
    end


    if previousState and isSamePos(_position, winPos) then
      win:move(previousState.positionj, previousState.screen)
      previousStates[winKey] = nil
      logger.d('reverted to previousState')
    else
      previousStates[winKey] = {screen = win:screen(), _position = winPos}
      win:move(_position)
      logger.d('saved previousState')
    end
    ext.centerOnTitle(win:frame())
  end
end

function mod.maximize()
  hs.window.focusedWindow():maximize()
end

local function isTableOfTables(t)
  for _, v in ipairs(t) do
    if type(v) ~= 'table' then
      return false
    end
  end
  return true
end

local function reverse(arr)
  local i, j = 1, #arr
  while i < j do
    arr[i], arr[j] = arr[j], arr[i]
    i = i + 1
    j = j - 1
  end
end

-- required for reseting the previous state.
local cycleStates = {}

-- cycles window size
function mod.setPosition(positions, positionsUltraWide, reversable)
  if not isTableOfTables(positions) then
    return mod.moveWindowTo(positions, positionsUltraWide)
  end

  local nextPosFn

  return function()
    local win = hs.window.frontmostWindow():focus()
    local _positions = positions
    if mod.isUltraWide(win) and positionsUltraWide then
      _positions = positionsUltraWide
    end
    local currentPos = toUnitRect(win)
    local id = win:id()

    if cycleStates[id] ~= _positions or not inPostions(currentPos, _positions) then
      nextPosFn = hs.fnutils.cycle(_positions)
    end

    local nextPos = nextPosFn()

    if isSamePos(nextPos, currentPos) then
      logger.d('same postion, using next')
      nextPos = nextPosFn()
    end

    cycleStates[id] = _positions

    win:move(nextPos)
    ext.centerOnTitle(win:frame())
  end
end

function mod.snapAll()
  hs.fnutils.each(hs.window.visibleWindows(), hs.grid.snap)
end

function mod.moveTo(pos)
  return function()
    hs.window.focusedWindow():move(pos)
    ext.centerOnTitle(pos)
  end
end

function mod.previousScreen()
  local win = hs.window.focusedWindow()
  win:moveToScreen(win:screen():previous())
end

function mod.nextScreen()
  local win = hs.window.focusedWindow()
  win:moveToScreen(win:screen():next())
end

local function maximizeOrCycleScreen()
  local win = hs.window.focusedWindow()
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
  ext.centerOnTitle(win:frame())
end

function mod.cycleScreenBack()
  local win, currentScreen = maximizeOrCycleScreen()
  if currentScreen then
    win:moveToScreen(currentScreen:previous())
  end
  ext.centerOnTitle(win:frame())
end

return mod
