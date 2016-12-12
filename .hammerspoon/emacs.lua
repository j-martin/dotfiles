local task = require "hs.task"
local logger = hs.logger.new('emacs', 'debug')
local application = require "hs.application"

local mod = {}

local function run(params)
  application.launchOrFocus('Emacs')
  task.new('/usr/local/bin/emacsclient', nil, logger.d, params):start()
end

local function eval(sexp)
  run({'--no-wait', '--quiet' , '--eval', sexp})
end

function mod.capture()
  eval('(org-capture)')
end

function mod.inbox()
  eval('(jm/open-inbox)')
end

function mod.agenda()
  eval('(org-agenda-list)')
end

return mod
