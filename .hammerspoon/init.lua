local alert = require "hs.alert"

local reload = require "utils/reload"
local bindings = require "bindings"
local audio = require "audio.headphones_watcher"
local battery = require "battery"

reload.init()
bindings.init()
battery.init()
audio.init()

alert.show("Config loaded")
