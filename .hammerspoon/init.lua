local alert = require "hs.alert"

local reload = require "utils/reload"
local bindings = require "bindings"
local audio = require "audio.headphones_watcher"
local battery = require "battery"
local reminder = require "reminder"

reload.init()
bindings.init()
battery.init()
audio.init()
reminder.init()

alert.show("Config loaded")
