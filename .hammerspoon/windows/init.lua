local ext = require 'windows/extensions'
local logger = hs.logger.new('windows', 'debug')

---@class WindowsModule
---@field launchOrCycleFocus fun(applicationName: string): fun()
---@field isUltraWideScreen fun(screen: hs.screen): boolean
---@field isUltraWide fun(win: hs.window): boolean
---@field hasUltraWideScreen fun(): boolean
---@field applyLayout fun(commonLayout: table[], selectedLayout: table[]): fun()
---@field moveWindowTo fun(position: table, positionsUltraWide: table[]|nil): fun()
---@field maximize fun()
---@field setPosition fun(positions: table[]|table, positionsUltraWide: table[]|nil, reversable: boolean|nil): fun()
---@field snapAll fun()
---@field moveTo fun(pos: table): fun()
---@field previousScreen fun()
---@field nextScreen fun()
---@field cycleScreen fun()
---@field cycleScreenBack fun()
local mod = {}

mod.launchOrCycleFocus = ext.launchOrCycleFocus

---@param screen hs.screen
---@return boolean
function mod.isUltraWideScreen(screen)
  local frame = screen:frame()
  return frame.w / frame.h > 2
end

---@param win hs.window
---@return boolean
function mod.isUltraWide(win)
  return mod.isUltraWideScreen(win:screen())
end

-- Returns true if any connected screen is an ultrawide.
---@return boolean
function mod.hasUltraWideScreen()
  return hs.fnutils.some(hs.screen.allScreens(), mod.isUltraWideScreen)
end

---@param commonLayout table[]
---@param selectedLayout table[]
---@return fun()
function mod.applyLayout(commonLayout, selectedLayout)
  ---@param entry table
  ---@return table
  local function expandLayout(entry)
    local scr
    if entry.screenFn then
      scr = entry.screenFn()
    else
      scr = hs.screen.primaryScreen():name()
    end
    return { entry.name, nil, scr, entry.pos, nil, nil }
  end

  return function()
    local completeLayout = hs.fnutils.map(hs.fnutils.concat(selectedLayout, commonLayout), expandLayout)
    hs.layout.apply(completeLayout)
  end
end

---@param win hs.window
---@return table
local function toUnitRect(win)
  ---@param value number
  ---@return number
  local function round(value)
    return math.ceil(value * 10) / 10
  end

  local unitRect = hs.fnutils.map(win:screen():toUnitRect(win:frame()), round)
  return { unitRect._x, unitRect._y, unitRect._w, unitRect._h }
end

---@param currentPos table
---@param previousPos table
---@return boolean
local function isSamePos(currentPos, previousPos)
  return currentPos[0] == previousPos[0]
    and currentPos[1] == previousPos[1]
    and currentPos[2] == previousPos[2]
    and currentPos[3] == previousPos[3]
end

---@param currentPos table
---@param positions table[]
---@return boolean
local function inPostions(currentPos, positions)
  for _, p in ipairs(positions) do
    if isSamePos(currentPos, p) then
      return true
    end
  end
  return false
end

local previousStates = {}

---@param position table[]
---@param positionsUltraWide table[]|nil
---@return fun()
function mod.moveWindowTo(position, positionsUltraWide)
  ---@param win hs.window
  ---@return string
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
      previousStates[winKey] = { screen = win:screen(), _position = winPos }
      win:move(_position)
      logger.d('saved previousState')
    end
    ext.centerOnTitle(win:frame())
  end
end

function mod.maximize()
  hs.window.focusedWindow():maximize()
end

---@param t table
---@return boolean
local function isTableOfTables(t)
  for _, v in ipairs(t) do
    if type(v) ~= 'table' then
      return false
    end
  end
  return true
end

---@param arr table
local function reverse(arr)
  local i, j = 1, #arr
  while i < j do
    arr[i], arr[j] = arr[j], arr[i]
    i = i + 1
    j = j - 1
  end
end

local cycleStates = {}

---@param positions table[]|table
---@param positionsUltraWide table[]|nil
---@param reversable boolean|nil
---@return fun()
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

---@param pos table
---@return fun()
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

---@return hs.window, hs.screen|nil
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
