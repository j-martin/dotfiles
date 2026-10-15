local utils = require 'apps/utils'

local mod = {}

local screenRatioNotch = 1125.0

local function clickNotification(offset_x, offset_y)
  local currentScreen = hs.mouse.getCurrentScreen()
  local currentPos = hs.mouse.getRelativePosition()
  local targetScreen = hs.screen.primaryScreen()
  local targetFrame = targetScreen:frame()

  if targetFrame.h == screenRatioNotch then
    offset_y = offset_y + 40
  end

  local targetPos = {x = targetFrame.w - offset_x, y = offset_y}

  hs.mouse.setRelativePosition(targetPos, targetScreen)
  utils.wait(5)
  hs.eventtap.leftClick(targetPos)
  hs.mouse.setRelativePosition(currentPos, currentScreen)
end

--- Clicks the latest notification.
function mod.open()
  -- Use offset_y=40 if hiding menu bar
  clickNotification(120, 70)
end

--- Clicks the close button of the latest notification.
function mod.close()
  -- Use offset_y=20 if hiding menu bar
  clickNotification(355, 50)
end

return mod
