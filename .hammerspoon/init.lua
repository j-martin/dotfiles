-- Loading this early before we load potentially broken code.
local reload = require "reload"
reload.init()

local apps = require "apps"
local audio = require "audio"
local battery = require "battery"
local keybindings = require "keybindings"
local meetingbar = require "meetingbar"
local usb = require "usb"

keybindings.init()
-- battery.init()
audio.init()
usb.init()
apps.init()
meetingbar.init()
require "hs.ipc"
if not hs.ipc.cliStatus("/opt/homebrew", true) then
  hs.ipc.cliInstall("/opt/homebrew")
end
hs.alert.show("Config loaded")
