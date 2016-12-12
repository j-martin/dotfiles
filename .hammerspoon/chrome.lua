local eventtap = require 'hs.eventtap'
local window = require 'hs.window'
local windows = require 'windows'

local mod = {}

mod.name = 'Google Chrome'

local previousTab = nil

local function switchTab()
  local tab = '1'
  if previousTab == '1' then
    tab = '2'
  end
  previousTab = tab
  eventtap.keyStroke({'cmd'}, tab)
end

function mod.inbox()
  local current = window.focusedWindow()
  local inbox = window.find("Inbox")

  local isChrome = current:application():title() == mod.name

  if current == inbox then
    switchTab()
  elseif inbox then
    inbox:unminimize()
    inbox:focus()
  elseif isChrome then
    switchTab()
    if not window.find("Inbox") then
      windows.launchOrCycleFocus(mod.name)()
      switchTab()
    end
  else
    windows.launchOrCycleFocus(mod.name)()
    switchTab()
  end
end

return mod
