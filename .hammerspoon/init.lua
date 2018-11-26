local alert = require "hs.alert"
local audio = require "audio"
local battery = require "battery"
local keybindings = require "keybindings"
local reload = require "utils/reload"
local usb = require "usb"

-- reload.init()
keybindings.init()
battery.init()
audio.init()
usb.init()

alert.show("Config loaded")
