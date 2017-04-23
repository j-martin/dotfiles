local fnutils = require 'hs.fnutils'
local hotkey = require 'hs.hotkey'
local grid = require 'hs.grid'
local hints = require 'hs.hints'
local caffeinate = require 'hs.caffeinate'
local windows = require 'windows'
local layout = require 'hs.layout'
local selection = require 'selection'
local audio = require 'audio'
local mode = require 'mode'
local emacs = require 'emacs'
local applications = require 'applications'
local reminder = require 'reminder'
local logger = hs.logger.new('bindings', 'debug')

local hyper = { 'cmd', 'alt', 'ctrl' }
local hyperShift = { 'cmd', 'alt', 'ctrl', 'shift' }

local mod = {}

--------------------------------------
-- binds functions to hyper key end --
--------------------------------------

hotkey.bind({ 'ctrl' }, 'tab', hints.windowHints)

local hyperBindings = {
  { key = '1', name = 'Activity Monitor' },
 -- key = '6' reserved for aText
  { key = '7', name = '1Password 6' },
  { key = '8', name = applications.name.slack },
  { key = '9', name = 'Spotify' },
  { key = '0', name = 'aText' },
  { key = '=', name = 'KeePassX' },
  { key = '-', name = 'Sequel Pro' },
  { key = 'a', fn = emacs.agenda },
  { key = 'e', name = 'Charles' },
  { key = 'b', fn = applications.openNotification },
  { key = 'b', fn = applications.openNotificationAction, shift = true },
  { key = 's', fn = windows.snapAll },
  { key = 'd', fn = selection.actOn },
  { key = 'f', name = 'Finder' },
  { key = 'y', fn = applications.inbox },
  { key = 'u', name = 'Emacs' },
  { key = 'i', name = 'iTerm2' },
  { key = 'o', name = 'IntelliJ IDEA.app' },
  { key = 'o', name = 'Gogland 1.0 EAP.app', shift = true },
  { key = 'p', name = 'Sublime Text' },
  { key = ';', name = 'Dash' },
  { key = 'l', name = applications.name.chrome },
  { key = 'l', fn = applications.chromeOmni, shift = true },
  { key = '\\', name = 'Paw' },
  { key = 'g', fn = windows.grid },
  { key = 'g', fn = windows.altGrid, shift = true },
  { key = 'h', fn = applications.slack },
  { key = 'h', fn = applications.slackUnread, shift = true },
  { key = 'j', pos = { { 0.0, 0.0, 0.5, 1.0}, { 0.0, 0.0, 0.7, 1.0} } },
  { key = 'j', pos = { 0.00, 0.00, 0.30, 1.00 }, shift = true },
  { key = 'k', pos = { { 0.5, 0.0, 0.5, 1.0}, { 0.3, 0.0, 0.7, 1.0} } },
  { key = 'k', pos = { 0.70, 0.00, 0.30, 1.00 }, shift = true },
  { key = 'z', fn = caffeinate.lockScreen },
  { key = 'x', fn = windows.previousScreen },
  { key = 'n', pos = { { 0.30, 0.00, 0.40, 1.00 }, { 0.20, 0.00, 0.60, 1.00 } } },
  { key = 'n', pos = { { 0.30, 0.05, 0.40, 0.60 }, { 0.20, 0.05, 0.60, 0.80 }, { 0.30, 0.05, 0.40, 0.30 } }, shift = true },
  { key = 'm', pos = { 0.00, 0.00, 1.00, 1.00 } },
  { key = 'v', name = 'Visual Studio Code' },
  { key = 'v', fn = selection.paste, shift = true },
  { key = 't', fn = emacs.capture },
  { key = 't', fn = emacs.inbox, shift = true },
  { key = 'c', fn = hs.toggleConsole, shift = true },
  { key = 'r', fn = hs.reload, shift = true },
  { key = 'up', fn = grid.resizeWindowShorter },
  { key = 'down', fn = grid.resizeWindowTaller },
  { key = 'left', fn = grid.resizeWindowThinner },
  { key = 'right', fn = grid.resizeWindowWider },
  { key = 'up', fn = grid.pushWindowUp, shift = true },
  { key = 'down', fn = grid.pushWindowDown, shift = true },
  { key = 'left', fn = grid.pushWindowLeft, shift = true },
  { key = 'right', fn = grid.pushWindowRight, shift = true },
}

-------------------------
-- create general mode --
-------------------------

local generalBindings = {
  { key = 's', fn = reminder.stretches },
  { key = 'd', fn = reminder.stop },
  { key = 'r', fn = reminder.reset },
  { key = 'j', fn = audio.next },
  { key = 'k', fn = audio.previous },
  { key = 'h', fn = audio.current },
  { key = 'y', fn = audio.changeVolume(-100) },
  { key = 'u', fn = audio.changeVolume(5) },
  { key = 'i', fn = audio.changeVolume(-5) },
  { key = 'o', fn = audio.setVolume(15) },
  { key = 'p', fn = audio.setVolume(30) },
  { key = ';', fn = audio.setVolume(50) },
  { key = '9', fn = audio.open },
  { key = 'l', fn = audio.playpause },
  { key = 'space', fn = audio.playpause },
}

------------------------
-- create layout mode --
------------------------

local commonLayout = {
  { name = "Inbox", screenFn = windows.alternateScreen, pos = { 0.00, 0.00, 1.00, 0.70 } },
  { name = "Slack", screenFn = windows.alternateScreen, pos = { 0.00, 0.30, 1.00, 0.70 } },
}

local modeLayouts = {
--                      x    y    w    h
  { key = '1', pos = { 0.00, 0.00, 0.50, 0.50 } },
  { key = '2', pos = { 0.50, 0.00, 0.50, 0.50 } },
  { key = '3', pos = { 0.00, 0.00, 1.00, 0.50 } },
  { key = 'q', pos = { 0.00, 0.50, 0.50, 0.50 } },
  { key = 'a', pos = { 0.00, 0.00, 0.50, 1.00 } },
  { key = 's', pos = { 0.50, 0.00, 0.50, 1.00 } },
  { key = 'w', pos = { 0.50, 0.50, 0.50, 0.50 } },
  { key = 'e', pos = { 0.00, 0.50, 1.00, 0.50 } },
  { key = 'h', pos = { 0.00, 0.00, 0.70, 1.00 } },
  { key = 'd', pos = { 0.10, 0.10, 0.80, 0.80 } },
  { key = 'f', pos = { 0.20, 0.20, 0.60, 0.60 } },
  { key = ';', pos = { 0.30, 0.00, 0.70, 1.00 } },
  { key = 'j', pos = { 0.00, 0.00, 0.30, 1.00 } },
  { key = 'k', pos = { 0.30, 0.00, 0.40, 1.00 } },
  { key = 'l', pos = { 0.70, 0.00, 0.30, 1.00 } },
  { key = '6', pos = { 0.00, 0.00, 0.70, 0.50 } },
  { key = '7', pos = { 0.00, 0.00, 0.30, 0.50 } },
  { key = '8', pos = { 0.30, 0.00, 0.40, 0.50 } },
  { key = '9', pos = { 0.70, 0.00, 0.30, 0.50 } },
  { key = '0', pos = { 0.30, 0.00, 0.70, 0.50 } },
  { key = 'y', pos = { 0.00, 0.50, 0.70, 0.50 } },
  { key = 'u', pos = { 0.00, 0.50, 0.30, 0.50 } },
  { key = 'i', pos = { 0.30, 0.50, 0.40, 0.50 } },
  { key = 'o', pos = { 0.70, 0.50, 0.30, 0.50 } },
  { key = 'p', pos = { 0.30, 0.50, 0.70, 0.50 } },
  { key = 'space', fn = hints.windowHints },
  { key = '=', fn = grid.resizeWindowWider },
  { key = '-', fn = grid.resizeWindowThinner },
  { key = 'm', fn = windows.cycleScreenBack },
  { key = 'n', fn = windows.cycleScreen },
  { key = 'z', layout = {
      { 'Emacs', layout.left50 },
      { 'iTerm2', layout.right50 },
      { 'Google Chrome', layout.right50 },
      { 'IntelliJ IDEA', layout.right50 },
      { 'Sublime Text', layout.right50 },
    }},
  { key = 'x', layout = {
      { 'Emacs', layout.left70 },
      { 'IntelliJ IDEA', layout.right70 },
      { 'Google Chrome', layout.right30 },
      { 'iTerm2', layout.right30 },
    }},
  { key = 'c', layout = {
      { 'Emacs', layout.left30 },
      { 'Google Chrome', layout.right70 },
      { 'IntelliJ IDEA', layout.right70 },
      { 'iTerm2', layout.right70 },
    }},
}

local function buildBindFunction(binding)
  if binding.pos then
    return windows.setPosition(binding.pos)
  elseif binding.layout then
    return windows.applyLayout(commonLayout, binding.layout)
  elseif binding.name then
    return windows.launchOrCycleFocus(binding.name)
  elseif binding.fn then
    return binding.fn
  end
end

local function buildLayoutBinding(binding)
  return { key = binding.key, fn = buildBindFunction(binding) }
end

local function bindToHyper(binding)
  local modifier = hyper

  if binding.shift then
    modifier = hyperShift
  end

  hotkey.bind(modifier, binding.key, buildBindFunction(binding))
end

function mod.init()
  fnutils.each(hyperBindings, bindToHyper)
  local layoutBindings = fnutils.map(modeLayouts, buildLayoutBinding)
  mode.create({'option'}, 'space', 'Layout', layoutBindings)
  mode.create(hyper, 'space', 'General', generalBindings)
end

return mod
