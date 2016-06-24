local fnutils = require 'hs.fnutils'
local tabs = require 'hs.tabs'
local hotkey = require 'hs.hotkey'
local grid = require 'hs.grid'
local caffeinate = require 'hs.caffeinate'
local windows = require 'windows'
local layout = require 'hs.layout'
local grid = require 'hs.grid'
local selection = require 'selection'
local audio = require 'audio'
local mode = require 'mode'

local hyper = {'cmd', 'alt', 'ctrl', 'shift'}

-- applications keybindings to hyper key
local applications = {
  { key = '7', name = '1Password 6' },
  { key = '8', name = 'Slack' },
  { key = '9', name = 'Spotify' },
  { key = '0', name = 'IntelliJ IDEA 14' },
  { key = '=', name = 'KeePassX' },
  { key = 'z', name = 'Sequel Pro' },
  { key = 'a', name = 'aText' },
  { key = 'f', name = 'Finder' },
  { key = 'y', name = 'Inbox', tab = true },
  { key = 'u', name = 'Emacs' },
  { key = 'i', name = 'iTerm2' },
  { key = 'o', name = 'IntelliJ IDEA.app' },
  { key = 'p', name = 'Sublime Text' },
  { key = ';', name = 'Dash' },
  { key = '1', name = 'Activity Monitor' },
  { key = 'l', name = 'Google Chrome' },
  { key = '\\', name = 'Paw', tab = true },
}


-- other bindings
hotkey.bind(hyper, 'v', caffeinate.lockScreen)
hotkey.bind(hyper, 's', windows.snapAll)
hotkey.bind(hyper, 'g', grid.show)
hotkey.bind(hyper, 'j', windows.cycleLeft)
hotkey.bind(hyper, 'k', windows.cycleRight)

hotkey.bind(hyper, 'm', windows.maximize)
hotkey.bind(hyper, 'x', windows.center40)

hotkey.bind(hyper, 'c', hs.toggleConsole)
hotkey.bind(hyper, 'r', hs.reload)
hotkey.bind(hyper, '-', selection.googleSelectedText)
hotkey.bind(hyper, 'e', selection.epochSinceNow)

local function bindToHyper(app)
  if app.tab then tabs.enableForApp(app.name) end
  hotkey.bind(hyper, app.key, windows.launchOrCycleFocus(app.name))
end

----------------------------------------------
-- binds the keys to the application above. --
----------------------------------------------

fnutils.each(applications, bindToHyper)

------------------------
-- create layout mode --
------------------------

local modeLayoutSets = {
  {
    key = 'z',
    layout = {
      {'Emacs', layout.left50},
      {'iTerm2', layout.right50},
      {'Google Chrome', layout.right50},
      {'IntelliJ IDEA', layout.right50},
      {'Sublime Text', layout.right50},
    }
  },
  {
    key = 'x',
    layout = {
      {'Emacs', layout.left70},
      {'IntelliJ IDEA', layout.right70},
      {'Google Chrome', layout.right30},
      {'iTerm2', layout.right30},
    }
  },
  {
    key = 'c',
    layout = {
      {'Emacs', layout.left30},
      {'Google Chrome', layout.right70},
      {'IntelliJ IDEA', layout.right70},
      {'iTerm2', layout.right70},
    }
  },
}

local laptopScreen = "Color LCD"

local commonLayout = {
  {"Inbox",  nil, laptopScreen, layout.left70, nil, nil},
  {"Slack",  nil, laptopScreen, layout.right50, nil, nil},
}

local modeLayouts = {
--                      x    y    w    h
  { key = '1', pos = { 0.0, 0.0, 0.5, 0.5 } },
  { key = '2', pos = { 0.5, 0.0, 0.5, 0.5 } },
  { key = 'q', pos = { 0.0, 0.5, 0.5, 0.5 } },
  { key = 'a', pos = { 0.0, 0.0, 0.5, 1.0 } },
  { key = 's', pos = { 0.5, 0.0, 0.5, 1.0 } },
  { key = 'w', pos = { 0.5, 0.5, 0.5, 0.5 } },
  { key = 'h', pos = { 0.0, 0.0, 0.7, 1.0 } },
  { key = 'e', pos = { 0.0, 0.0, 1.0, 0.5 } },
  { key = 'd', pos = { 0.0, 0.5, 1.0, 0.5 } },
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
  { key = 'n', fn = windows.cycleScreenBack },
  { key = 'm', fn = windows.cycleScreen },
}

local function layoutToFn(binding)
  return {
    key = binding.key,
    fn = binding.fn or windows.applyLayout(commonLayout, binding.layout)
  }
end

local function postionToFn(binding)
  return {
    key = binding.key,
    fn = binding.fn or windows.moveTo(binding.pos)
  }
end

local layoutBindings = fnutils.concat(
  fnutils.map(modeLayouts, postionToFn),
  fnutils.map(modeLayoutSets, layoutToFn)
)

mode.create({'option'}, 'space', 'Layout', layoutBindings)

-----------------------
-- create audio mode --
-----------------------

local audioBindings = {
  { key = 'j', fn = audio.next },
  { key = 'k', fn = audio.previous },
  { key = 'h', fn = audio.current },
  { key = 'u', fn = audio.changeVolume(-100) },
  { key = 'i', fn = audio.changeVolume(10) },
  { key = 'o', fn = audio.changeVolume(-10) },
  { key = '9', fn = audio.open},
  { key = 'l', fn = audio.playpause },
  { key = 'space', fn = audio.playpause },
}

mode.create(hyper, 'space', 'Audio', audioBindings)
