-- Loading this early before we load potentially broken code.
---@class HammerspoonBootstrap
---@field init fun(): nil
local reload = require 'reload'
reload.init()

local timer = require 'utils/timer'
timer.start()

require 'config'

local activity = require 'activity'
local apps = require 'apps'
local audio = require 'audio'
local githubReviews = require 'github_reviews'
local keybindings = require 'keybindings'
local slackTodos = require 'slack_todos'
local snippets = require 'snippets'
local snippetsGenerator = require 'snippets/generator'
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
snippetsGenerator.init()
timer.alert('Config loaded')
