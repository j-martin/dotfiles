local application = require "hs.application"
local logger = hs.logger.new('emacs', 'debug')
local osascript = require "hs.osascript"
local pasteboard = require "hs.pasteboard"
local task = require "hs.task"
local uielement = require "hs.uielement"
local window = require "hs.window"
local selection = require "selection"
local http = require "hs.http"
local process = require "utils/process"

local mod = {}

local function eval(sexp)
  process.start('/usr/local/bin/emacsclient', {'--no-wait', '--quiet' , '--eval', sexp})
  application.launchOrFocus('Emacs')
end

local function open(url)
  process.start('/usr/local/bin/emacsclient', {'--no-wait', '--quiet' , url})
  application.launchOrFocus('Emacs')
end

function mod.capture()
  eval('(org-capture)')
end

function mod.inbox()
  eval('(jm/open-inbox)')
end

function mod.references()
  eval('(jm/open-references)')
end

function mod.orgSearchView()
  eval('(org-search-view)')
end

function mod.workInbox()
  eval('(jm/open-work)')
end

function mod.agenda()
  eval('(org-agenda-list)')
end

function mod.orgCaptureProtocol(captureTemplate)
  return function()
    local focussedApplication = window.focusedWindow():application()

    local title = "(from " .. focussedApplication:name() .. ")"
    local url = focussedApplication:path()
    local body = selection.getSelectedText()

    if focussedApplication:name() == 'Google Chrome' then
      _, title, _ = osascript.javascript("Application('Google Chrome').windows[0].activeTab().title()")
      _, url, _ = osascript.javascript("Application('Google Chrome').windows[0].activeTab().url()")
    end

    if focussedApplication:name() == 'Finder' then
      _, title, _ = osascript.javascript("Application('Finder').selection()[0].name()")
      _, url, _ = osascript.javascript("Application('Finder').selection()[0].url()")
    end

    local protocolUrl = 'org-protocol://capture?' ..
      'template=' .. captureTemplate ..
      '&title=' .. http.encodeForQuery(title) ..
      '&url=' .. http.encodeForQuery(url) ..
      '&body=' .. http.encodeForQuery(body or '')
    -- logger.df("URL: %s", protocolUrl)
    open(protocolUrl)
  end
end

return mod
