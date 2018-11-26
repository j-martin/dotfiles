local alert = require "hs.alert"
local eventtap = require 'hs.eventtap'
local mouse = require 'hs.mouse'
local screen = require 'hs.screen'
local timer = require 'hs.timer'
local window = require 'hs.window'
local windows = require 'windows'

local mod = {}

mod.name = {
  activityMonitor = 'Activity Monitor',
  chrome = 'Google Chrome',
  inbox = ' Mail', -- extra characters to be more specific
  noisyTyper = 'NoisyTyper',
  slack  = 'Slack'
}

local states = {
  noisyTyperEnabled = false
}

local function wait(n)
  local n = n or 1
  timer.usleep(10000 * n)
end

local previousTab = nil

function switchToAndType(application, modifier, keystroke)
  windows.launchOrCycleFocus(application)()
  wait()
  eventtap.keyStroke(modifier, keyStroke)
end

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

function mod.slackQuickSwitcher()
  switchToAndType(mod.name.slack, {'cmd'}, '1')
  wait()
  eventtap.keyStroke({'cmd'}, 't')
end

function mod.slackReactionEmoji(chars)
  return function()
    eventtap.keyStroke({'cmd', 'shift'}, '\\')
    wait()
    eventtap.keyStrokes(chars)
    wait(20)
    eventtap.keyStroke({}, 'return')
  end
end

function mod.slackUnread()
  switchToAndType(mod.name.slack, {'cmd'}, '1')
  wait()
  eventtap.keyStroke({'cmd', 'shift'}, 'a')
end

function mod.activityMonitor()
  switchToAndType(mod.name.activityMonitor, {'cmd'}, '2')
  local win = hs.window.focusedWindow()
  local laptopScreen = 'Color LCD'

  win:moveToScreen(laptopScreen)
  win:moveToUnit({ 0.85, 0.9, 0.1, 0.1 }, 0)
  eventtap.keyStroke({'cmd'}, '1')
end

function mod.toggleNoisyTyper()
  return function()
    local callBackFn = nil
    if not states.noisyTyperEnabled then
      callBackFn = function()
        win = window.frontmostWindow()
        hs.application.launchOrFocus(mod.name.noisyTyper)
        wait(4)
        eventtap.keyStroke({}, 'return')
        win:focus()
        states.noisyTyperEnabled = true
      end
    end
    args = {'-f', mod.name.noisyTyper}
    states.noisyTyperEnabled = false
    hs.task.new('/usr/bin/pkill', callBackFn, function() end, args):start()
  end
end

function mod.chromeOmni()
  switchToAndType(mod.name.chrome, {'shift'}, 't')
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
