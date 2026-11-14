-- Loading this early before we load potentially broken code.
---@class HammerspoonBootstrap
---@field init fun(): nil
local reload = require 'reload'
reload.init()

require 'config'

local activity = require 'activity'
local apps = require 'apps'
local audio = require 'audio'
local githubReviews = require 'github_reviews'
local keybindings = require 'keybindings'
local slackTodos = require 'slack_todos'
local snippets = require 'snippets'
local usb = require 'usb'
local wifi = require 'wifi'

keybindings.init()
activity.init()
audio.init()
usb.init()
wifi.init()
apps.init()
githubReviews.init()
slackTodos.init()
snippets.init()
hs.alert.show('Config loaded')
