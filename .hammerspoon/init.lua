-- Loading this early before we load potentially broken code.
---@class HammerspoonBootstrap
---@field init fun(): nil
local reload = require 'reload'
reload.init()

local activity = require 'activity'
local apps = require 'apps'
local audio = require 'audio'
local keybindings = require 'keybindings'
local usb = require 'usb'

keybindings.init()
activity.init()
audio.init()
usb.init()
apps.init()
require 'hs.ipc'
if not hs.ipc.cliStatus('/opt/homebrew', true) then
  hs.ipc.cliInstall('/opt/homebrew')
end
hs.alert.show('Config loaded')
