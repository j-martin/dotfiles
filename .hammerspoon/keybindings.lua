local apps = require 'apps'
local audio = require 'audio'
local keybinder = require 'keybinder'
local mode = require 'mode'
local screen = require 'screen'
local selection = require 'selection'
local windows = require 'windows'
local reload = require 'reload'
local usb = require 'usb'

---@class BindingTableEntry
---@field key string
---@field fn function|nil
---@field name string|nil
---@field desc string|nil
---@field modifiers string[]|nil
---@field shift boolean|nil
---@field pos table[]|nil
---@field posUltraWide table[]|nil
---@field reversable boolean|nil
---@field remap table|nil

---@class KeybindingsModule
---@field init fun()
local cmd = keybinder.cmd
local cmdCtrl = { 'cmd', 'ctrl' }
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
      { key = '1', name = apps.activityMonitor.name, shift = true },
      { key = '8', name = 'Slack' },
      { key = '9', name = 'Music' },
      { key = '9', shift = true, name = 'Nintendo Music' },
      { key = '\\', name = '1Password' },
      { key = 'a', name = 'Figma' },
      { key = 'b', fn = apps.notificationCenter.open, desc = 'Notification - Open' },
      { key = 'b', fn = apps.notificationCenter.close, shift = true, desc = 'Notification - Action' },
      { key = 'c', name = 'Google Calendar' },
      { key = 'd', fn = selection.actOn('google'), desc = 'Search selection' },
      { key = 'f', name = 'Finder' },
      { key = 'f', name = 'Preview', shift = true },
      { key = 'g', name = 'Claude' },
      { key = 'i', name = 'iTerm2' },
      { key = 'i', fn = apps.iterm.omni, shift = true },
      {
        key = 'j',
        pos = { { 0.0, 0.0, 0.5, 1.0 }, { 0.0, 0.0, 0.7, 1.0 } },
        posUltraWide = { { 0.00, 0.00, 0.30, 1.00 }, { 0.0, 0.0, 0.4, 1.0 } },
        desc = 'Window - Left',
      },
      {
        key = 'j',
        pos = { { 0.00, 0.00, 0.30, 1.00 }, { 0.00, 0.00, 0.70, 1.00 } },
        shift = true,
        desc = 'Window - Left (alt)',
      },
      {
        key = 'k',
        pos = { { 0.5, 0.0, 0.5, 1.0 }, { 0.3, 0.0, 0.7, 1.0 } },
        posUltraWide = { { 0.70, 0.00, 0.30, 1.00 }, { 0.6, 0.0, 0.4, 1.0 } },
        desc = 'Window - Right',
      },
      {
        key = 'k',
        pos = { { 0.70, 0.00, 0.30, 1.00 }, { 0.30, 0.00, 0.70, 1.00 } },
        shift = true,
        desc = 'Window - Right (alt)',
      },
      { key = 'l', name = 'Brave Browser' },
      {
        key = 'n',
        pos = { { 0.25, 0.00, 0.50, 1.00 }, { 0.20, 0.00, 0.60, 1.00 } },
        posUltraWide = { { 0.30, 0.00, 0.40, 1.00 }, { 0.25, 0.00, 0.50, 1.00 } },
        reversable = true,
        desc = 'Window - Center',
      },
      {
        key = 'n',
        pos = { { 0.30, 0.10, 0.40, 0.60 }, { 0.20, 0.10, 0.60, 0.80 } },
        posUltraWide = { { 0.35, 0.10, 0.30, 0.60 }, { 0.20, 0.10, 0.60, 0.80 } },
        shift = true,
        desc = 'Window - Center (small)',
      },
      { key = 'm', pos = { 0.00, 0.00, 1.00, 1.00 }, desc = 'Full Screen (Current)' },
      { key = 'm', fn = windows.previousScreen, shift = true, desc = 'Move window the next screen' },
      { key = 'o', name = apps.goland.name },
      { key = 'o', name = apps.idea.name, shift = true },
      { key = 'p', name = 'Sublime Text' },
      { key = 'p', name = 'Preview', shift = true },
      { key = 'q', fn = hs.toggleConsole, shift = true, desc = 'HS - Console' },
      { key = 'r', name = 'Reminders' },
      { key = 'r', shift = true, fn = apps.reminders.add, desc = 'Reminders - Add' },
      { key = 's', name = 'Obsidian' },
      { key = 't', fn = apps.emacs.capture(), desc = 'Org - Capture' },
      { key = 't', fn = apps.emacs.inbox, shift = true, desc = 'Org - Inbox' },
      { key = 'u', name = 'Emacs' },
      { key = 'u', fn = apps.emacs.helmBuffers, shift = true },
      { key = 'v', fn = selection.paste, shift = true, desc = 'Paste - Type' },
      { key = 'w', fn = apps.emacs.workInbox, shift = true, desc = 'Org - Show work' },
      { key = 'y', name = 'Gmail' },
      { key = 'z', name = 'Google Meet' },
      { key = 'z', fn = apps.googleMeet.toggleMute, shift = true, desc = 'Google Meet - Toggle Mute' },
      { key = '-', fn = hs.grid.resizeWindowShorter, shift = true, desc = 'Windows - Shorter' },
      { key = '=', fn = hs.grid.resizeWindowTaller, shift = true, desc = 'Windows - Taller' },
      { key = 'up', fn = hs.grid.pushWindowUp, shift = true, desc = 'Windows - Up' },
      { key = 'down', fn = hs.grid.pushWindowDown, shift = true, desc = 'Windows - Down' },
      { key = 'left', fn = hs.grid.pushWindowLeft, shift = true, desc = 'Windows - Left' },
      { key = 'right', fn = hs.grid.pushWindowRight, shift = true, desc = 'Windows - Right' },
    },
  },
  {
    name = apps.brave.name,
    bindings = {
      { modifiers = cmdCtrl, key = 'u', fn = apps.brave.slackReactionEmoji('thup'), desc = 'Thumbs up' },
      { modifiers = cmdCtrl, key = 's', fn = apps.brave.slackReactionEmoji('slighsm'), desc = 'Smiling Face' },
      { modifiers = cmdCtrl, key = 'e', fn = apps.brave.slackReactionEmoji('heart'), desc = 'Heart' },
      { modifiers = cmdCtrl, key = 'return', fn = apps.brave.clickSignIn, desc = 'Press the Sign in button' },
      { modifiers = cmdCtrl, key = 'o', fn = apps.brave.openActiveTabInSafari, desc = 'Open tab in Safari' },
      { modifiers = cmdCtrl, key = 'g', fn = apps.brave.openActiveTabInChrome, desc = 'Open tab in Google Chrome' },
    },
  },
  {
    name = apps.googleChrome.name,
    bindings = {
      {
        modifiers = cmdCtrl,
        key = 'g',
        fn = apps.googleChrome.openActiveTabInDefaultBrowser,
        desc = 'Open tab in default browser',
      },
    },
  },
  {
    name = apps.safari.name,
    bindings = {
      {
        modifiers = cmdCtrl,
        key = 'o',
        fn = apps.safari.openActiveTabInDefaultBrowser,
        desc = 'Open tab in default browser',
      },
    },
  },
  {
    name = 'Messages',
    bindings = {
      { modifiers = cmd, key = 'k', remap = { modifiers = cmd, key = 'f' }, desc = 'Search conversations' },
    },
  },
}

----------------
-- hyper mode --
----------------

local hyperModeBindings = {
  { key = '/', fn = keybinder.showBindings, exitMode = true, desc = 'List hyper keybindings' },
  { key = '9', fn = audio.open, desc = 'Spotify' },
  { key = 'a', fn = audio.pickOutputDevice, exitMode = true, desc = 'Audio - Pick output device' },
  { key = 'b', fn = screen.setBrightness(0.8), desc = 'Set brightness to 80%.' },
  { key = 'c', fn = usb.officeAutomation('coffee', 'on'), desc = 'Turn coffee machine on' },
  { key = 'd', fn = usb.officeAutomation('desk', 'on'), desc = 'Turn desk on' },
  { key = 'f', fn = usb.officeAutomation('desk', 'off'), desc = 'Turn desk off' },
  { key = 'e', fn = usb.officeAutomation('office_call', 'on') },
  { key = 'w', fn = usb.officeAutomation('office_call', 'off'), shift = true },
  { key = 'h', fn = audio.current, desc = 'Current song' },
  { key = 'i', fn = audio.changeVolume(-5), desc = 'Decrease the volume by 5%' },
  { key = 'j', fn = audio.next, desc = 'Next song' },
  { key = 'k', fn = audio.previous, desc = 'Previous song' },
  { key = 'm', fn = audio.pickInputDevice, exitMode = true, desc = 'Audio - Pick input device' },
  { key = 'o', fn = audio.setVolume('default'), desc = 'Default volume level' },
  { key = 'p', fn = audio.setVolume(100), desc = 'High volume level' },
  { key = 'r', fn = reload.reload, desc = 'Reloading configuration ...' },
  { key = 'space', fn = audio.playpause, exitMode = true, desc = 'Pause or resume Music' },
  { key = 'u', fn = audio.changeVolume(5), desc = 'Increase the volume by 5%' },
  { key = 'x', fn = apps.messages.sendSelection, exitMode = true, desc = 'iMessage - Send selection' },
  { key = 'y', fn = audio.changeVolume(-100), desc = 'Mute' },
}

function mod.init()
  keybinder.init(bindings)
  mode.create(hyper, 'space', 'Hyper', hyperModeBindings)
end

return mod
