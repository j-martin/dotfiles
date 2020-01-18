local apps = require 'apps'
local audio = require 'audio'
local keybinder = require 'keybinder'
local emacs = require 'emacs'
local grid = require 'hs.grid'
local mode = require 'mode'
local mounts = require 'mounts'
local screen = require 'screen'
local selection = require 'selection'
local windows = require 'windows'
local chrome = require 'chrome'
local reload = require 'utils/reload'

local cmd = keybinder.cmd
local cmdCtrl = {'cmd', 'ctrl'}
local hyper = keybinder.hyper

local mod = {}

-----------------------------
-- binding per application --
-----------------------------

-- Default is hyper

local bindings = {
  {
    name = keybinder.globalBindings,
    bindings = {
      -- cmd + h reserved for notification
      {modifiers = cmd, key = 'm', name = 'Ripcord'},
      {key = '1', name = apps.name.activityMonitor},
      {key = '1', fn = apps.activityMonitor, shift = true, desc = 'Activity Monitor with CPU Graph'},
      {key = '2', name = 'Keybase'}, -- key = '5' reserved for Alfred snippets
      {key = '8', name = apps.name.ripcord},
      {key = '8', fn = apps.ripcordQuickSwitcher, shift = true},
      {key = '9', name = 'Spotify'},
      {key = '9', name = 'Soundcleod', shift = true},
      {key = ';', name = 'Dash'},
      {key = '\\', name = '1Password 7'}, -- key = ';' reserved for Dash
      {key = 'a', fn = emacs.agenda, desc = 'Org Agenda'},
      {key = 'b', fn = apps.openNotification, desc = 'Notification - Open'},
      {key = 'b', fn = apps.openNotificationAction, shift = true, desc = 'Notification - Action'},
      {key = 'd', fn = selection.actOn('google'), desc = 'Search selection'},
      {key = 'f', name = 'Finder'},
      {key = 'f', name = 'Preview', shift = true},
      {key = 'i', name = 'iTerm2'},
      {key = 'i', fn = apps.iTermOmni, shift = true},
      {key = 'j', pos = {{0.0, 0.0, 0.5, 1.0}, {0.0, 0.0, 0.7, 1.0}}, desc = 'Window - Left 50% <-> 30%'},
      {
        key = 'j',
        pos = {{0.00, 0.00, 0.30, 1.00}, {0.00, 0.00, 0.70, 1.00}},
        shift = true,
        desc = 'Window - Left 30% <-> 70%',
      },
      {key = 'k', pos = {{0.5, 0.0, 0.5, 1.0}, {0.3, 0.0, 0.7, 1.0}}, desc = 'Window - Right 50% <-> 30%'},
      {
        key = 'k',
        pos = {{0.70, 0.00, 0.30, 1.00}, {0.30, 0.00, 0.70, 1.00}},
        shift = true,
        desc = 'Window - Right 30% <-> 70%',
      },
      {key = 'l', name = chrome.name},
      {key = 'l', fn = chrome.openOmni, shift = true, desc = 'Google Chrome - Omni Tab'},
      {
        key = 'n',
        pos = {{0.25, 0.00, 0.50, 1.00}, {0.20, 0.00, 0.60, 1.00}},
        reversable = true,
        desc = 'Window - Center 50% <-> 60%',
      },
      {
        key = 'n',
        pos = {{0.30, 0.10, 0.40, 0.60}, {0.20, 0.10, 0.60, 0.80}},
        shift = true,
        desc = 'Window - Center (small) 40% <-> 60%',
      },
      {key = 'm', pos = {0.00, 0.00, 1.00, 1.00}, targetScreen = 'current', desc = 'Full Screen (Current)'},
      {key = 'm', fn = windows.previousScreen, shift = true, desc = 'Move window the next screen'},
      {key = 'o', name = apps.name.idea},
      {key = 'o', fn = apps.ideaOmni, shift = true},
      {key = 'p', name = 'Visual Studio Code'},
      {key = 'q', fn = hs.toggleConsole, shift = true, desc = 'HS - Console'},
      {key = 'r', fn = emacs.orgRifle, desc = 'Org - Capture selection to Resources'},
      {key = 'r', fn = emacs.references, shift = true, desc = 'Org - Show Resources'},
      {key = 's', name = 'Sublime Text'},
      {key = 's', fn = windows.snapAll, shift = true, desc = 'Windows - Snap'},
      {key = 't', fn = emacs.capture(), desc = 'Org - Capture'},
      {key = 't', fn = emacs.inbox, shift = true, desc = 'Org - Inbox'},
      {key = 'u', name = 'Emacs'},
      {key = 'u', fn = emacs.helmBuffers, shift = true}, -- key v, reserved for Alfred paste
      {key = 'v', fn = selection.paste, shift = true, desc = 'Paste - Type'},
      {key = 'w', fn = emacs.capture('w'), desc = 'Org - Capture selection to Work'},
      {key = 'w', fn = emacs.workInbox, shift = true, desc = 'Org - Show work'},
      {key = 'y', tab = chrome.tab.mail.work, desc = 'Switch to Inbox'},
      {key = 'z', name = 'Charles'},
      {key = '-', fn = grid.resizeWindowShorter, shift = true, desc = 'Windows - Shorter'},
      {key = '=', fn = grid.resizeWindowTaller, shift = true, desc = 'Windows - Taller'},
      {key = '-', fn = grid.resizeWindowThinner, desc = 'Windows - Thinner'},
      {key = '=', fn = grid.resizeWindowWider, desc = 'Windows - Wider'},
      {key = 'up', fn = grid.pushWindowUp, shift = true, desc = 'Windows - Up'},
      {key = 'down', fn = grid.pushWindowDown, shift = true, desc = 'Windows - Down'},
      {key = 'left', fn = grid.pushWindowLeft, shift = true, desc = 'Windows - Left'},
      {key = 'right', fn = grid.pushWindowRight, shift = true, desc = 'Windows - Right'},
    },
  },
  {
    name = chrome.name,
    bindings = {
      {modifiers = cmdCtrl, key = 'u', fn = chrome.slackReactionEmoji('thup'), desc = 'Thumbs up'},
      {modifiers = cmdCtrl, key = 's', fn = chrome.slackReactionEmoji('slighsm'), desc = 'Smiling Face'},
      {modifiers = cmdCtrl, key = 'e', fn = chrome.slackReactionEmoji('heart'), desc = 'Heart'},
    },
  },
}

----------------
-- hyper mode --
----------------

local hyperModeBindings = {
  {key = '9', fn = audio.open, desc = 'Spotify'},
  {key = 'b', fn = screen.setBrightness(0.8), desc = 'Set brightness to 80%.'},
  {key = 'e', fn = mounts.unmountAll, desc = 'Unmount all volumes'},
  {key = 'h', fn = audio.current, desc = 'Current song'},
  {key = 'i', fn = audio.changeVolume(-5), desc = 'Decrease the volume by 5%'},
  {key = 'j', fn = audio.next, desc = 'Next song'},
  {key = 'k', fn = audio.previous, desc = 'Previous song'},
  {key = 'o', fn = audio.setVolume(15), desc = 'Default volume level'},
  {key = 'p', fn = audio.setVolume(30), desc = 'High volume level'},
  {key = 'r', fn = reload.reload, desc = 'Reloading configuration ...'},
  {key = 'space', fn = audio.playpause, exitMode = true, desc = 'Pause or resume Spotify'},
  {key = 'u', fn = audio.changeVolume(5), desc = 'Increase the volume by 5%'},
  {key = 'y', fn = audio.changeVolume(-100), desc = 'Mute'},
}

function mod.init()
  keybinder.init(bindings)
  mode.create(hyper, 'space', 'Hyper', hyperModeBindings)
end

return mod
