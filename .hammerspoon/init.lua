local alert = require "hs.alert"
local audio = require "audio"
local battery = require "battery"
local keybindings = require "keybindings"
local usb = require "usb"

keybindings.init()
battery.init()
audio.init()
usb.init()

alert.show("Config loaded")
