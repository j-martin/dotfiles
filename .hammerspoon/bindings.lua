local fnutils = require "hs.fnutils"
local tabs = require "hs.tabs"
local hotkey = require "hs.hotkey"
local grid = require "hs.grid"
local window = require "hs.window"
local caffeinate = require "hs.caffeinate"
local windows = require "windows"

-- applications keybindings to hyper key
local applications = {
  {key = "8", name = "Slack"},
  {key = "=", name = "KeePassX"},
  {key = "9", name = "Spotify"},
  {key = "Z", name = "Sequel Pro"},
  {key = "A", name = "aText"},
  {key = "P", name = "Sublime Text"},
  {key = "F", name = "Finder"},
  {key = "U", name = "Emacs", tab = true},
  {key = "O", name = "IntelliJ IDEA"},
  {key = "I", name = "iTerm"},
  {key = "7", name = "1Password 6"},
  {key = ";", name = "Dash"},
  {key = "Y", name = "Inbox", tab = true},
  {key = "0", name = "IntelliJ IDEA 14"},
  {key = "1", name = "Activity Monitor"},
  {key = "L", name = "Google Chrome"},
  {key = "\\", name = "Paw", tab = true},
}

local hyper = {"cmd", "alt", "ctrl", "shift"}

local function bindToHyper(app)
  if app.tab then tabs.enableForApp(app.name) end
  hotkey.bind(hyper, app.key, windows.launchOrCycleFocus(app.name))
end

-- binds the keys to the application above.
fnutils.each(applications, bindToHyper)

hotkey.bind(hyper, "R", hs.reload)
hotkey.bind(hyper, "V", caffeinate.lockScreen)
hotkey.bind(hyper, "M", grid.show)
hotkey.bind(hyper, "space", windows.pickLayout)
hotkey.bind(hyper, "J", function() windows.cycleWidth(0) end)
hotkey.bind(hyper, "K", function() windows.cycleWidth(1) end)
hotkey.bind(hyper, "N", windows.maximize)
hotkey.bind(hyper, "X", windows.center40)
