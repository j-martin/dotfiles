local apps = require "apps"
local audio = require "audio"
local battery = require "battery"
local keybindings = require "keybindings"
local usb = require "usb"

keybindings.init()
-- battery.init()
-- audio.init()
usb.init()
apps.init()
-- hs.ipc.cliInstall("/opt/homebrew")

hs.alert.show("Config loaded")
