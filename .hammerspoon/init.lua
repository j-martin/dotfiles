-- Loading this early before we load potentially broken code.
---@class HammerspoonBootstrap
---@field init fun(): nil
local reload = require 'reload'
reload.init()

require 'config'

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
hs.alert.show('Config loaded')
