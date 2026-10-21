local utils = require 'apps/utils'

local mod = {}

mod.name = 'Activity Monitor'

--- Shows the Activity Monitor CPU history in a small window on the laptop screen.
function mod.open()
  utils.switchToAndType(mod.name, { 'cmd' }, '2')
  local win = hs.window.focusedWindow()
  local laptopScreen = 'Color LCD'

  win:moveToScreen(laptopScreen)
  win:moveToUnit({ 0.85, 0.9, 0.1, 0.1 }, 0)
  hs.eventtap.keyStroke({ 'cmd' }, '1')
end

return mod
