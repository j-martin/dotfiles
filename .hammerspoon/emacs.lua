local logger = hs.logger.new('emacs', 'debug')
local process = require "utils/process"
local selection = require "selection"

local mod = {}

local function eval(sexp)
  process.start('~/.bin/ec', {'--quiet', '--suppress-output', '--eval', sexp})
  hs.application.launchOrFocus('Emacs')
end

local function evalInCurrentBuffer(sexp)
  eval('(with-current-buffer (window-buffer (selected-window)) ' .. sexp .. ')')
end

local function open(url)
  process.start('~/.bin/ec', {'--quiet', '--suppress-output', url})
  hs.application.launchOrFocus('Emacs')
end

function mod.helmBuffers()
  eval('(helm-mini)')
end

function mod.inbox()
  eval('(jm/open-inbox)')
end

function mod.references()
  eval('(jm/open-references)')
end

function mod.orgRifle()
  eval('(helm-org-rifle)')
end

function mod.workInbox()
  eval('(jm/open-inbox)')
end

function mod.agenda()
  eval('(org-agenda-list)')
end

function mod.capture(captureTemplate)
  return function()
    local focusedWindow = hs.window.focusedWindow()
    local focusedApplication = focusedWindow:application()

    if focusedApplication:name() == 'Emacs' then
      evalInCurrentBuffer('(org-capture)')
      return
    end

    local title = focusedWindow:title() .. " - " .. focusedApplication:name()
    local url = focusedApplication:path()
    local body = selection.getSelectedText()

    if focusedApplication:name() == 'Brave Browser' then
      _, title, _ = hs.osascript.javascript("Application('Brave Browser').windows[0].activeTab().title()")
      _, url, _ = hs.osascript.javascript("Application('Brave Browser').windows[0].activeTab().url()")
    end

    if focusedApplication:name() == 'Finder' then
      _, title, _ = hs.osascript.javascript("Application('Finder').selection()[0].name()")
      _, url, _ = hs.osascript.javascript("Application('Finder').selection()[0].url()")
    end

    local protocolUrl = 'org-protocol://capture?' .. 'title=' .. hs.http.encodeForQuery(title) .. '&url='
                          .. hs.http.encodeForQuery(url) .. '&body=' .. hs.http.encodeForQuery(body or '')
    if captureTemplate then
      protocolUrl = protocolUrl .. '&template=' .. captureTemplate
    end

    logger.df("URL: %s", protocolUrl)
    open(protocolUrl)
  end
end

return mod
