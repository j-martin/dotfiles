local fnutils = require 'hs.fnutils'
local hotkey = require 'hs.hotkey'
local grid = require 'hs.grid'
local hints = require 'hs.hints'
local caffeinate = require 'hs.caffeinate'
local brightness = require 'hs.brightness'
local windows = require 'windows'
local layout = require 'hs.layout'
local selection = require 'selection'
local audio = require 'audio'
local mode = require 'mode'
local emacs = require 'emacs'
local applications = require 'applications'
local logger = hs.logger.new('bindings', 'debug')
local screen = require 'screen'
local mounts = require 'mounts'

local hyper = { 'cmd', 'alt', 'ctrl' }
local hyperShift = { 'cmd', 'alt', 'ctrl', 'shift' }

local mod = {}

--------------------------------------
-- binds functions to hyper key end --
--------------------------------------

hotkey.bind({ 'ctrl' }, 'tab', hints.windowHints)

local hyperBindings = {
  { key = '1', name = applications.name.activityMonitor },
  { key = '1', fn = applications.activityMonitor, shift = true },
  { key = '2', name = 'Keybase' },
  { key = '4', fn = applications.toggleNoisyTyper() },
  -- key = '5' reserved for snippets
  { key = '7', name = 'Paw' },
  { key = '8', name = applications.name.slack },
  { key = '9', name = 'Spotify' },
  { key = ';', name = 'Dash' },
  { key = '\\', name = '1Password 7' },
  { key = 'a', fn = emacs.agenda },
  { key = 'b', fn = applications.openNotification },
  { key = 'b', fn = applications.openNotificationAction, shift = true },
  { key = 'd', fn = selection.actOn },
  { key = 'e', name = 'Bee' },
  { key = 'f', name = 'Finder' },
  { key = 'f', name = 'Preview', shift = true },
  { key = 'g', fn = windows.altGrid, shift = true },
  { key = 'g', fn = windows.grid },
  { key = 'h', fn = applications.slack },
  { key = 'h', fn = applications.slackUnread, shift = true },
  { key = 'i', name = 'iTerm2' },
  { key = 'j', pos = { { 0.0, 0.0, 0.5, 1.0}, { 0.0, 0.0, 0.7, 1.0} } },
  { key = 'j', pos = { { 0.00, 0.00, 0.30, 1.00 }, { 0.00, 0.00, 0.70, 1.00 } }, shift = true },
  { key = 'k', pos = { { 0.5, 0.0, 0.5, 1.0}, { 0.3, 0.0, 0.7, 1.0} } },
  { key = 'k', pos = { { 0.70, 0.00, 0.30, 1.00 }, { 0.30, 0.00, 0.70, 1.00 } }, shift = true },
  { key = 'l', fn = applications.chromeOmni, shift = true },
  { key = 'l', name = applications.name.chrome },
  { key = 'm', pos = { 0.00, 0.00, 1.00, 1.00 } },
  { key = 'm', pos = { 0.00, 0.00, 1.00, 1.00 }, shift = true, targetScreen = 'current' },
  { key = 'n', pos = { { 0.25, 0.00, 0.50, 1.00 }, { 0.20, 0.00, 0.60, 1.00 } }, reversable = true },
  { key = 'n', pos = { { 0.30, 0.10, 0.40, 0.60 }, { 0.20, 0.10, 0.60, 0.80 } }, shift = true },
  { key = 'o', name = 'IntelliJ IDEA 2018.3 EAP.app' },
  { key = 'p', name = 'Visual Studio Code' },
  { key = 'q', fn = hs.toggleConsole, shift = true },
  { key = 'r', fn = emacs.references },
  { key = 'r', fn = hs.reload, shift = true },
  { key = 's', name = 'Sublime Text' },
  { key = 's', fn = windows.snapAll, shift = true },
  { key = 't', fn = emacs.capture },
  { key = 't', fn = emacs.inbox, shift = true },
  { key = 'u', name = 'Emacs' },
  { key = 'v', fn = selection.paste, shift = true },
  { key = 'w', fn = emacs.workInbox, shift = true },
  { key = 'x', fn = windows.previousScreen },
  { key = 'y', fn = applications.inbox },
  { key = 'z', name = 'Charles' },
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
-- create hyper mode --
-------------------------

local hyperModeBindings = {
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
  { key = 'space', fn = audio.playpause, exitMode = true },
}

-------------------------
-- create general mode --
-------------------------

local generalModeBindings = {
  { key = 'e', fn = mounts.unmountAll },
  { key = 'b', fn = screen.setBrightness(0.8) },
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
  { key = 'space', name = 'Alfred 3', exitMode = true },
}

------------------------
-- create layout mode --
------------------------

local commonLayout = {
  { name = "Inbox", screenFn = windows.alternateScreen, pos = { 0.00, 0.00, 1.00, 0.70 } },
  { name = "Slack", screenFn = windows.alternateScreen, pos = { 0.00, 0.30, 1.00, 0.70 } },
}

local function buildBindFunction(binding)
  if binding.pos and binding.targetScreen then
    return windows.setPosition(binding.pos, binding.targetScreen, binding.reversable)
  elseif binding.pos then
    return windows.setPosition(binding.pos, 'primary', binding.reversable)
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
  mode.create(hyper, 'space', 'Hyper', hyperModeBindings)
  mode.create({'cmd'}, 'space', 'General', generalModeBindings)

  hotkey.bind({'cmd'}, 'h', applications.slack)
  hotkey.bind({'cmd'}, 'm', windows.cycleScreen)
end

return mod
