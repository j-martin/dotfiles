local alert = require "hs.alert"

local reload = require "utils/reload"
local bindings = require "bindings"
local audio = require "audio.headphones_watcher"
local battery = require "battery"
local reminder = require "reminder"
local usb = require "usb"

reload.init()
bindings.init()
battery.init()
audio.init()
reminder.init()
usb.init()

notifications = hs.distributednotifications.new(function(name, object, userInfo)
    print(string.format("name: %s\nobject: %s\nuserInfo: %s\n", name, object, hs.inspect(userInfo)))
end):start()

alert.show("Config loaded")
