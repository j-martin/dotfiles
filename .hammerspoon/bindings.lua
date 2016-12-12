local fnutils = require 'hs.fnutils'
local tabs = require 'hs.tabs'
local hotkey = require 'hs.hotkey'
local grid = require 'hs.grid'
local caffeinate = require 'hs.caffeinate'
local windows = require 'windows'
local layout = require 'hs.layout'
local selection = require 'selection'
local audio = require 'audio'
local mode = require 'mode'
local emacs = require 'emacs'
local chrome = require 'chrome'
local reminder = require 'reminder'
local logger = hs.logger.new('bindings', 'debug')

local hyper = { 'cmd', 'alt', 'ctrl' }
local hyperShift = { 'cmd', 'alt', 'ctrl', 'shift' }

local mod = {}

--------------------------------------
-- binds functions to hyper key end --
--------------------------------------

local hyperBindings = {
  { key = '1', name = 'Activity Monitor' },
  { key = '7', name = '1Password 6' },
  { key = '8', name = 'Slack' },
  { key = '9', name = 'Spotify' },
  { key = '0', name = 'aText' },
  { key = '=', name = 'KeePassX' },
  { key = '-', name = 'Sequel Pro' },
  { key = 'a', fn = emacs.agenda },
  { key = 'e', name = 'Charles' },
  { key = 's', fn = windows.snapAll },
  { key = 'd', fn = selection.actOn },
  { key = 'f', name = 'Finder' },
  { key = 'y', fn = chrome.inbox },
  { key = 'u', name = 'Emacs' },
  { key = 'i', name = 'iTerm2' },
  { key = 'o', name = 'IntelliJ IDEA.app' },
  { key = 'p', name = 'Sublime Text' },
  { key = ';', name = 'Dash' },
  { key = 'l', name = chrome.name },
  { key = '\\', name = 'Paw', tab = true },
  { key = 'g', fn = grid.show },
  { key = 'j', fn = windows.cycleLeft },
  { key = 'j', pos = { 0.0, 0.0, 0.3, 1.0 }, shift = true },
  { key = 'k', fn = windows.cycleRight },
  { key = 'k', pos = { 0.7, 0.0, 0.3, 1.0 }, shift = true },
  { key = 'z', fn = caffeinate.lockScreen },
  { key = 'x', fn = windows.previousScreen },
  { key = 'c', pos = { 0.3, 0.1, 0.4, 0.6 } },
  { key = 'n', pos = { 0.3, 0.0, 0.4, 1.0 } },
  { key = 'n', pos = { 0.2, 0.0, 0.6, 1.0 }, shift = true },
  { key = 'm', pos = { 0.0, 0.0, 1.0, 1.0 } },
  { key = 'v', fn = selection.paste, shift = true },
  { key = 't', fn = emacs.capture },
  { key = 't', fn = emacs.inbox, shift = true },
  { key = 'q', fn = hs.toggleConsole },
  { key = 'r', fn = hs.reload },
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
  { name = "Inbox", screenFn = windows.alternateScreen, pos = { 0.0, 0.0, 1.0, 0.7 } },
  { name = "Slack", screenFn = windows.alternateScreen, pos = { 0.0, 0.3, 1.0, 0.7 } },
}

local modeLayouts = {
--                      x    y    w    h
  { key = '1', pos = { 0.0, 0.0, 0.5, 0.5 } },
  { key = '2', pos = { 0.5, 0.0, 0.5, 0.5 } },
  { key = '3', pos = { 0.0, 0.0, 1.0, 0.5 } },
  { key = 'q', pos = { 0.0, 0.5, 0.5, 0.5 } },
  { key = 'a', pos = { 0.0, 0.0, 0.5, 1.0 } },
  { key = 's', pos = { 0.5, 0.0, 0.5, 1.0 } },
  { key = 'w', pos = { 0.5, 0.5, 0.5, 0.5 } },
  { key = 'e', pos = { 0.0, 0.5, 1.0, 0.5 } },
  { key = 'h', pos = { 0.0, 0.0, 0.7, 1.0 } },
  { key = 'd', pos = { 0.1, 0.1, 0.8, 0.8 } },
  { key = 'f', pos = { 0.2, 0.2, 0.6, 0.6 } },
  { key = ';', pos = { 0.3, 0.0, 0.7, 1.0 } },
  { key = 'j', pos = { 0.0, 0.0, 0.3, 1.0 } },
  { key = 'k', pos = { 0.3, 0.0, 0.4, 1.0 } },
  { key = 'l', pos = { 0.7, 0.0, 0.3, 1.0 } },
  { key = '6', pos = { 0.0, 0.0, 0.7, 0.5 } },
  { key = '7', pos = { 0.0, 0.0, 0.3, 0.5 } },
  { key = '8', pos = { 0.3, 0.0, 0.4, 0.5 } },
  { key = '9', pos = { 0.7, 0.0, 0.3, 0.5 } },
  { key = '0', pos = { 0.3, 0.0, 0.7, 0.5 } },
  { key = 'y', pos = { 0.0, 0.5, 0.7, 0.5 } },
  { key = 'u', pos = { 0.0, 0.5, 0.3, 0.5 } },
  { key = 'i', pos = { 0.3, 0.5, 0.4, 0.5 } },
  { key = 'o', pos = { 0.7, 0.5, 0.3, 0.5 } },
  { key = 'p', pos = { 0.3, 0.5, 0.7, 0.5 } },
  { key = 'space', pos = { 0.0, 0.0, 1.0, 1.0 } },
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
    return windows.moveToPrimaryScreen(binding.pos)
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

  if binding.tab and binding.name then
    logger.d(binding.name)
    tabs.enableForApp(binding.name)
  end

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
