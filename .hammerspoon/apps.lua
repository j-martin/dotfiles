local alert = require "hs.alert"
local eventtap = require 'hs.eventtap'
local mouse = require 'hs.mouse'
local screen = require 'hs.screen'
local timer = require 'hs.timer'
local window = require 'hs.window'
local windows = require 'windows'
local logger = hs.logger.new('apps', 'debug')

local mod = {}

mod.name = {
  activityMonitor = 'Activity Monitor',
  noisyTyper = 'NoisyTyper',
}

local states = {
  noisyTyperEnabled = false
}

local function wait(n)
  local n = n or 1
  timer.usleep(10000 * n)
end

function mod.switchToAndType(application, modifiers, keyStroke)
  windows.launchOrCycleFocus(application)()
  wait()
  eventtap.keyStroke(modifiers, keyStroke)
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

function mod.activityMonitor()
  mod.switchToAndType(mod.name.activityMonitor, {'cmd'}, '2')
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

return mod
