local eventtap = require 'hs.eventtap'
local window = require 'hs.window'
local screen = require 'hs.screen'
local mouse = require 'hs.mouse'
local timer = require 'hs.timer'
local windows = require 'windows'
local alert = require "hs.alert"

local mod = {}

mod.name = {
  chrome = 'Google Chrome',
  inbox = 'Inbox - ', -- extra characters to be more specific
  noisyTyper = 'NoisyTyper',
  slack  = 'Slack'
}

local states = {
  noisyTyperEnabled = false
}

local function wait()
  timer.usleep(10000)
end

local previousTab = nil

local function switchTab()
  local tab = '1'
  if previousTab == '1' then
    tab = '2'
  end
  previousTab = tab
  eventtap.keyStroke({'cmd'}, tab)
  alert('Tab ' .. tab, 0.4)
end

local function clickNotification(offset)
  local currentScreen = mouse.getCurrentScreen()
  local currentPos = mouse.getRelativePosition()
  local targetScreen = screen.primaryScreen()
  local targetPos = { x = targetScreen:frame().w - offset, y = 40 }

  mouse.setRelativePosition(targetPos, targetScreen)
  eventtap.leftClick(targetPos)
  mouse.setRelativePosition(currentPos, currentScreen)
end

function mod.openNotification()
  clickNotification(160)
end

function mod.openNotificationAction()
  clickNotification(40)
end

function mod.slack()
  windows.launchOrCycleFocus(mod.name.slack)()
  wait()
  eventtap.keyStroke({'cmd'}, '1')
  wait()
  eventtap.keyStroke({'cmd'}, 't')
end

function mod.slackUnread()
  mod.slack()
  wait()
  eventtap.keyStrokes('allunread')
  wait()
  eventtap.keyStroke({}, 'return')
end

function mod.toggleNoisyTyper()
  return function()
    local cb = nil
    if not states.noisyTyperEnabled then
      cb = function()
        win = window.frontmostWindow()
        hs.application.launchOrFocus(mod.name.noisyTyper)
        wait()
        wait()
        eventtap.keyStroke({}, 'return')
        win:focus()
        states.noisyTyperEnabled = true
      end
    end
    args = {'-f', mod.name.noisyTyper}
    states.noisyTyperEnabled = false
    hs.task.new('/usr/bin/pkill', cb, function() end, args):start()
  end
end

function mod.chromeOmni()
  windows.launchOrCycleFocus(mod.name.chrome)()
  wait()
  eventtap.keyStroke({'shift'}, 't')
end

function mod.inbox()
  local current = window.focusedWindow()
  local inbox = window.find(mod.name.inbox)

  local isChrome = current:application():title() == mod.name

  if current == inbox then
    switchTab()
  elseif inbox then
    inbox:unminimize()
    inbox:focus()
  elseif isChrome then
    switchTab()
    if not window.find(name.inbox) then
      windows.launchOrCycleFocus(mod.name.chrome)()
      switchTab()
    end
  else
    windows.launchOrCycleFocus(mod.name.chrome)()
    switchTab()
  end
end

return mod
