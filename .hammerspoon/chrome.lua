local eventtap = require 'hs.eventtap'
local window = require 'hs.window'
local windows = require 'windows'

local mod = {}

mod.name = 'Google Chrome'

local previousWindow = nil

function mod.inbox()
  local current = window.focusedWindow()
  local win = window.find("Inbox")
  if current == win then
    previousWindow:focus()
  else
    previousWindow = current
    if win then
      win:unminimize()
      win:focus()
    else
      windows.launchOrCycleFocus(mod.name)()
      eventtap.keyStroke({'cmd'}, '1')
    end
  end
end

return mod
