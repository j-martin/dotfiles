local alert = require "hs.alert"
logger = hs.logger.new('root', 'debug')

require "utils/reload"
require "bindings"

local audio = require "audio.headphones_watcher"

audio.init()
alert.show("Config loaded")
