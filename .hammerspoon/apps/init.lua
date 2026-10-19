local logger = hs.logger.new('apps', 'info')
local utils = require 'apps/utils'

local mod = {
  activityMonitor = require 'apps/activity_monitor',
  brave = require 'apps/brave',
  emacs = require 'apps/emacs',
  finder = require 'apps/finder',
  goland = require 'apps/goland',
  googleChrome = require 'apps/google_chrome',
  googleMeet = require 'apps/google_meet',
  idea = require 'apps/idea',
  iterm = require 'apps/iterm',
  meetingbar = require 'apps/meetingbar',
  messages = require 'apps/messages',
  notificationCenter = require 'apps/notification_center',
  reminders = require 'apps/reminders',
  safari = require 'apps/safari',
  slack = require 'apps/slack',
  zoom = require 'apps/zoom',
}

local registered = {}
for _, app in pairs(mod) do
  if app.name then
    registered[app.name] = app
  end
end

local listeners = {}

--- Calls `fn(appName, event, app)` on every application event, for any application.
function mod.subscribe(fn)
  table.insert(listeners, fn)
end

local function onApplicationEvent(appName, event, app)
  local registeredApp = registered[appName]
  if registeredApp and registeredApp.onApplicationEvent then
    registeredApp.onApplicationEvent(event, app)
  end
  for _, listener in ipairs(listeners) do
    listener(appName, event, app)
  end
end

--- Returns what the window is showing, when its app supports it, as
--- {title, url, details = {lines}, selection}. `selection` is only set when the app knows it better than the clipboard.
function mod.context(window)
  local app = window and window:application()
  local registeredApp = app and registered[app:name()]
  if not registeredApp or not registeredApp.context then
    return nil
  end
  local ok, context = pcall(registeredApp.context, window)
  if not ok then
    logger.ef('Failed to get the %s context: %s', app:name(), context)
    return nil
  end
  return context
end

mod.lastUrl = nil

--- Opens http(s) URLs in their desktop app when possible, e.g. Zoom and Slack, and in Brave otherwise.
function mod.httpCallback(scheme, host, params, fullUrl, senderPID)
  logger.i(scheme, host, hs.inspect(params), fullUrl, senderPID)
  local bundleId = 'com.brave.Browser'
  local url = fullUrl
  if mod.lastUrl == fullUrl then
    logger.i("Same URL as before. Defaulting to Chrome...")
    utils.open(bundleId, fullUrl)
    return
  end

  mod.lastUrl = fullUrl

  local encodedParams = ''
  if next(params) then
    encodedParams = fullUrl:gsub('.*?', '')
  end

  if not host then
    logger.i("No host, assuming it is a file.")
    hs.urlevent.openURL(url:gsub('^http:[ab]/', 'file://'))
    return
  end

  if host:match('.*.zoom.us$') then
    bundleId = mod.zoom.bundleId
    url = mod.zoom.deepLink(fullUrl, encodedParams)
  elseif fullUrl:match('https://.*.slack.com/archives/.*') then
    local deepLink = mod.slack.deepLink(fullUrl, encodedParams)
    if deepLink then
      bundleId = mod.slack.bundleId
      url = deepLink
    else
      logger.w("Could not infer the 'slack://' from the URL. Defaulting to your browser redirect.")
    end
  end
  utils.open(bundleId, url)
end

--- Starts the application watcher, and the app specific watchers.
function mod.init()
  -- Keep a reference so the watcher is not garbage collected.
  mod.watcher = hs.application.watcher.new(onApplicationEvent):start()
  mod.slack.init()
  -- hs.urlevent.httpCallback = mod.httpCallback
  -- hs.urlevent.slackCallback = logger.i
  -- hs.urlevent.setDefaultHandler('http')
  mod.googleChrome.init()
  mod.meetingbar.init()
end

return mod
