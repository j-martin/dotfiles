local apps = require 'apps'
local audio = require 'audio'
local keybinder = require 'keybinder'
local emacs = require 'emacs'
local mode = require 'mode'
local mounts = require 'mounts'
local screen = require 'screen'
local selection = require 'selection'
local windows = require 'windows'
local chrome = require 'chrome'
local reload = require 'utils/reload'
local usb = require 'usb'
local wifi = require 'wifi'

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
      {key = '1', name = apps.name.activityMonitor},
      {key = '1', fn = apps.activityMonitor, shift = true, desc = 'Activity Monitor with CPU Graph'},
      -- key = '5' reserved for Alfred snippets
      {key = '8', name = 'Slack'},
      {key = '9', name = 'Spotify'},
      {key = '\\', name = '1Password'},
      {key = 'a', name = 'Figma'},
      {key = 'b', fn = apps.openNotification, desc = 'Notification - Open'},
      {key = 'b', fn = apps.closeNotification, shift = true, desc = 'Notification - Action'},
      {key = 'c', name = 'Google Calendar'},
      {key = 'd', fn = selection.actOn('google'), desc = 'Search selection'},
      {key = 'f', name = 'Finder'},
      {key = 'f', name = 'Preview', shift = true},
      {key = 'i', name = 'iTerm2'},
      {key = 'i', fn = apps.iTermOmni, shift = true},
      {
        key = 'j',
        pos = {{0.0, 0.0, 0.5, 1.0}, {0.0, 0.0, 0.7, 1.0}},
        posUltraWide = {{0.00, 0.00, 0.30, 1.00}, {0.0, 0.0, 0.4, 1.0}},
        desc = 'Window - Left'
      },
      {
        key = 'j',
        pos = {{0.00, 0.00, 0.30, 1.00}, {0.00, 0.00, 0.70, 1.00}},
        shift = true,
        desc = 'Window - Left (alt)',
      },
      {
        key = 'k',
        pos = {{0.5, 0.0, 0.5, 1.0}, {0.3, 0.0, 0.7, 1.0}},
        posUltraWide = {{0.70, 0.00, 0.30, 1.00}, {0.6, 0.0, 0.4, 1.0}},
        desc = 'Window - Right'},
      {
        key = 'k',
        pos = {{0.70, 0.00, 0.30, 1.00}, {0.30, 0.00, 0.70, 1.00}},
        shift = true,
        desc = 'Window - Right (alt)',
      },
      {key = 'l', name = chrome.name},
      {key = 'l', shift = true, name = 'Brave Browser'},
      {
        key = 'n',
        pos = {{0.25, 0.00, 0.50, 1.00}, {0.20, 0.00, 0.60, 1.00} },
        posUltraWide = {{0.30, 0.00, 0.40, 1.00}, {0.25, 0.00, 0.50, 1.00}},
        reversable = true,
        desc = 'Window - Center',
      },
      {
        key = 'n',
        pos = {{0.30, 0.10, 0.40, 0.60}, {0.20, 0.10, 0.60, 0.80}},
        posUltraWide = {{0.35, 0.10, 0.30, 0.60}, {0.20, 0.10, 0.60, 0.80}},
        shift = true,
        desc = 'Window - Center (small)',
      },
      {key = 'm', pos = {0.00, 0.00, 1.00, 1.00}, desc = 'Full Screen (Current)'},
      {key = 'm', fn = windows.previousScreen, shift = true, desc = 'Move window the next screen'},
      {key = 'o', name = apps.name.idea},
      {key = 'o', fn = apps.ideaOmni, shift = true},
      {key = 'e', fn = usb.officeAutomation('office_call', 'on')},
      {key = 'e', fn = usb.officeAutomation('office_call', 'off'), shift = true},
      {key = 'p', name = 'Sublime Text'},
      {key = 'p', name = 'Preview', shift = true},
      {key = 'q', name = 'Tuple'},
      {key = 'q', fn = hs.toggleConsole, shift = true, desc = 'HS - Console'},
      {key = 'r', fn = emacs.orgRifle, desc = 'Org - Capture selection to Resources'},
      {key = 'r', fn = emacs.references, shift = true, desc = 'Org - Show Resources'},
      {key = 's', name = 'Cursor'},
      {key = 't', fn = emacs.capture(), desc = 'Org - Capture'},
      {key = 't', fn = emacs.inbox, shift = true, desc = 'Org - Inbox'},
      {key = 'u', name = 'Emacs'},
      {key = 'u', fn = emacs.helmBuffers, shift = true},
      -- key v, reserved for Alfred paste
      {key = 'v', fn = selection.paste, shift = true, desc = 'Paste - Type'},
      {key = 'w', fn = emacs.capture('w'), desc = 'Org - Capture selection to Work'},
      {key = 'w', fn = emacs.workInbox, shift = true, desc = 'Org - Show work'},
      {key = 'y', name = 'Gmail'},
      {key = 'z', name = 'Google Meet'},
      {key = 'z', fn = apps.googleMeetToggleMute, shift = true, desc = 'Google Meet - Toggle Mute'},
      {key = '-', fn = hs.grid.resizeWindowShorter, shift = true, desc = 'Windows - Shorter'},
      {key = '=', fn = hs.grid.resizeWindowTaller, shift = true, desc = 'Windows - Taller'},
      {key = '-', fn = hs.grid.resizeWindowThinner, desc = 'Windows - Thinner'},
      {key = '=', fn = hs.grid.resizeWindowWider, desc = 'Windows - Wider'},
      {key = 'up', fn = hs.grid.pushWindowUp, shift = true, desc = 'Windows - Up'},
      {key = 'down', fn = hs.grid.pushWindowDown, shift = true, desc = 'Windows - Down'},
      {key = 'left', fn = hs.grid.pushWindowLeft, shift = true, desc = 'Windows - Left'},
      {key = 'right', fn = hs.grid.pushWindowRight, shift = true, desc = 'Windows - Right'},
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
  {key = 'c', fn = usb.officeAutomation('coffee', 'on'), desc = 'Turn coffee machine on'},
  {key = 'd', fn = usb.officeAutomation('desk', 'on'), desc = 'Turn desk on'},
  {key = 'f', fn = usb.officeAutomation('desk', 'off'), desc = 'Turn desk off'},
  {key = 'e', fn = mounts.unmountAll, desc = 'Unmount all volumes'},
  {key = 'h', fn = audio.current, desc = 'Current song'},
  {key = 'i', fn = audio.changeVolume(-5), desc = 'Decrease the volume by 5%'},
  {key = 'j', fn = audio.next, desc = 'Next song'},
  {key = 'k', fn = audio.previous, desc = 'Previous song'},
  {key = 'o', fn = audio.setVolume('default'), desc = 'Default volume level'},
  {key = 'p', fn = audio.setVolume(100), desc = 'High volume level'},
  {key = 'r', fn = reload.reload, desc = 'Reloading configuration ...'},
  {key = 'space', fn = audio.playpause, exitMode = true, desc = 'Pause or resume Spotify'},
  {key = 'u', fn = audio.changeVolume(5), desc = 'Increase the volume by 5%'},
  {key = 'y', fn = audio.changeVolume(-100), desc = 'Mute'},
  {key = 'w', fn = wifi.restartWifi, desc = 'Restart WiFi'},
  {key = 'z', fn = usb.workSetup, desc = 'Work setup'},
}

function mod.init()
  keybinder.init(bindings)
  mode.create(hyper, 'space', 'Hyper', hyperModeBindings)
end

return mod
