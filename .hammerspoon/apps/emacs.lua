local logger = hs.logger.new('emacs', 'debug')
local process = require 'utils/process'
local selection = require 'selection'
local utils = require 'apps/utils'

---@class EmacsApp
---@field name string
---@field helmBuffers fun()
---@field inbox fun()
---@field references fun()
---@field orgRifle fun()
---@field workInbox fun()
---@field agenda fun()
---@field capture fun(captureTemplate: string|nil): fun()
---@field context fun(): table<string, any>|nil
local mod = {}

mod.name = 'Emacs'

local emacsclientPath = utils.getExecPath('emacsclient')

---@param sexp string
local function eval(sexp)
  process.start('~/.bin/ec', { '--quiet', '--suppress-output', '--eval', sexp })
  hs.application.launchOrFocus(mod.name)
end

---@param sexp string
local function evalInCurrentBuffer(sexp)
  eval('(with-current-buffer (window-buffer (selected-window)) ' .. sexp .. ')')
end

---@param url string
local function open(url)
  process.start('~/.bin/ec', { '--quiet', '--suppress-output', url })
  hs.application.launchOrFocus(mod.name)
end

--- Lists the buffers.
function mod.helmBuffers()
  eval('(helm-mini)')
end

--- Opens the org inbox.
function mod.inbox()
  eval('(jm/open-inbox)')
end

--- Opens the org references.
function mod.references()
  eval('(jm/open-references)')
end

--- Searches the org files.
function mod.orgRifle()
  eval('(helm-org-rifle)')
end

--- Opens the work org inbox.
function mod.workInbox()
  eval('(jm/open-inbox)')
end

--- Opens the org agenda.
function mod.agenda()
  eval('(org-agenda-list)')
end

-- Falls back to the window title and the application path for apps without context.
---@param window hs.window
---@return table<string, any>
local function captureContext(window)
  local apps = require 'apps'
  local context = apps.context(window) or {}
  local app = window:application()
  return {
    title = context.title or (window:title() .. ' - ' .. app:name()),
    url = context.url or app:path(),
    body = context.selection or selection.getSelectedText(),
  }
end

--- Returns a callback capturing the focused window, with its link and selected text, with org-protocol.
---@param captureTemplate string|nil
---@return fun()
function mod.capture(captureTemplate)
  return function()
    local focusedWindow = hs.window.focusedWindow()

    if focusedWindow:application():name() == mod.name then
      evalInCurrentBuffer('(org-capture)')
      return
    end

    local context = captureContext(focusedWindow)
    local protocolUrl = 'org-protocol://capture?'
      .. 'title='
      .. hs.http.encodeForQuery(context.title)
      .. '&url='
      .. hs.http.encodeForQuery(context.url)
      .. '&body='
      .. hs.http.encodeForQuery(context.body or '')
    if captureTemplate then
      protocolUrl = protocolUrl .. '&template=' .. captureTemplate
    end

    logger.df('URL: %s', protocolUrl)
    open(protocolUrl)
  end
end

-- Single quotes are avoided so the expression can be single quoted for the shell
local contextSexp = [[
(with-current-buffer (window-buffer (selected-window))
  (base64-encode-string
   (encode-coding-string
    (json-encode
     (list (cons (quote buffer) (buffer-name))
           (cons (quote file) buffer-file-name)
           (cons (quote directory) default-directory)
           (cons (quote mode) (symbol-name major-mode))
           (cons (quote line) (line-number-at-pos))
           (cons (quote heading) (and (derived-mode-p (quote org-mode)) (ignore-errors (org-get-heading t t t t))))
           (cons (quote region) (and (use-region-p) (buffer-substring-no-properties (region-beginning) (region-end))))))
     (quote utf-8))
    t))]]

--- Returns the current buffer, its file and line, org heading, and active region.
---@return table<string, any>|nil
function mod.context()
  local output, ok = hs.execute(emacsclientPath .. " --eval '" .. contextSexp:gsub('\n', ' ') .. "' 2>/dev/null")
  local encoded = ok and output:match('"([%w+/=]+)"')
  local buffer = encoded and hs.json.decode(hs.base64.decode(encoded))
  if not buffer then
    logger.wf('Could not get the Emacs buffer context: %s', output)
    return nil
  end
  local details = {}
  if buffer.heading then
    table.insert(details, '* ' .. buffer.heading)
  end
  table.insert(details, buffer.mode)
  return {
    title = buffer.buffer,
    url = buffer.file and (buffer.file .. ':' .. math.floor(buffer.line)) or buffer.directory,
    details = details,
    selection = buffer.region or '',
  }
end

return mod
