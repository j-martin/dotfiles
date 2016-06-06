local fnutils = require "hs.fnutils"
local tabs = require "hs.tabs"
local hotkey = require "hs.hotkey"
local grid = require "hs.grid"
local caffeinate = require "hs.caffeinate"
local windows = require "windows"
local layout = require "hs.layout"

-- applications keybindings to hyper key
local applications = {
  { key = '8', name = 'Slack' },
  { key = '=', name = 'KeePassX' },
  { key = '9', name = 'Spotify' },
  { key = 'z', name = 'Sequel Pro' },
  { key = 'a', name = 'aText' },
  { key = 'p', name = 'Sublime Text' },
  { key = 'f', name = 'Finder' },
  { key = 'u', name = 'Emacs' },
  { key = 'o', name = 'IntelliJ IDEA.app' },
  { key = 'i', name = 'iTerm' },
  { key = '7', name = '1Password 6' },
  { key = ';', name = 'Dash' },
  { key = 'y', name = 'Inbox', tab = true },
  { key = '0', name = 'IntelliJ IDEA 14' },
  { key = '1', name = 'Activity Monitor' },
  { key = 'l', name = 'Google Chrome' },
  { key = '\\', name = 'Paw', tab = true },
}

local hyper = {'cmd', 'alt', 'ctrl', 'shift'}

local function bindToHyper(app)
  if app.tab then tabs.enableForApp(app.name) end
  hotkey.bind(hyper, app.key, windows.launchOrCycleFocus(app.name))
end

-- binds the keys to the application above.
fnutils.each(applications, bindToHyper)

-- setup layouts
local layoutChoices = {
  {
    text = "50/50",
    subText = "50/50",
    layout = {
      {"Emacs", layout.left50},
      {"iTerm2", layout.right50},
      {"Google Chrome", layout.right50},
      {"IntelliJ IDEA", layout.right50},
      {"Sublime Text", layout.right50},
    }
  },
  {
    text = "70/30",
    subText = "70/30",
    layout = {
      {"Emacs", layout.left70},
      {"IntelliJ IDEA", layout.right70},
      {"Google Chrome", layout.right30},
      {"iTerm2", layout.right30},
    }
  },
  {
    text = "30/70",
    subText = "30/70",
    layout = {
      {"Emacs", layout.left30},
      {"Google Chrome", layout.right70},
      {"IntelliJ IDEA", layout.right70},
      {"iTerm2", layout.right70},
    }
  },
}

hotkey.bind(hyper, "space", windows.pickLayout(layoutChoices))

-- setup modal layout
local mLayouts = {
--                      x    y    w    h
  { key = '1', pos = { 0.0, 0.0, 0.5, 0.5 } },
  { key = '2', pos = { 0.5, 0.0, 0.5, 0.5 } },
  { key = 'q', pos = { 0.0, 0.5, 0.5, 0.5 } },
  { key = 'w', pos = { 0.5, 0.5, 0.5, 0.5 } },
  { key = 'h', pos = { 0.0, 0.0, 0.7, 1.0 } },
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
}

windows.modalLayout(hotkey.modal.new({'option'}, 'space'), mLayouts)

-- other bindings
hotkey.bind(hyper, "v", caffeinate.lockScreen)
hotkey.bind(hyper, "m", grid.show)
hotkey.bind(hyper, "s", windows.snapAll)

hotkey.bind(hyper, "j", windows.cycleLeft)
hotkey.bind(hyper, "k", windows.cycleRight)

hotkey.bind(hyper, "n", windows.maximize)
hotkey.bind(hyper, "x", windows.center40)

hotkey.bind(hyper, "c", hs.toggleConsole)
hotkey.bind(hyper, "r", hs.reload)
