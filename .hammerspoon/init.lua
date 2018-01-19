local alert = require "hs.alert"

local reload = require "utils/reload"
local bindings = require "bindings"
local audio = require "audio.headphones_watcher"
local battery = require "battery"
local schedule = require "schedule"
local usb = require "usb"
local ipc = require "hs.ipc"

-- reload.init()
bindings.init()
battery.init()
audio.init()
schedule.init()
usb.init()

if not ipc.cliStatus() then
  ipc.cliInstall()
end

alert.show("Config loaded")
