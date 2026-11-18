local logger = hs.logger.new('brave', 'debug')
local utils = require 'apps/utils'
local chromium = require 'apps/chromium'
local googleChrome = require 'apps/google_chrome'
local googleMeet = require 'apps/google_meet'
local appGuard = require 'utils/app_guard'
local jxa = require 'utils/jxa'
local config = require 'config'

---@class BraveApp
---@field name string
---@field tab table<string, string|table<string, string>>
---@field slackQuickSwitcher fun()
---@field slackReactionEmoji fun(chars: string): function
---@field slackUnread fun()
---@field openOmni fun()
---@field clickSignIn fun()
---@field activateTab fun(name: string): fun(): boolean
---@field context fun(): table<string, any>|nil
---@field openActiveTabInSafari fun()
---@field openActiveTabInChrome fun()
---@field chromeOnlyTitles string[]
---@field chromeOnlyUrlPrefixes string[]
---@field meetUrlPrefixes string[]
---@field moveDelay number
---@field moveTabs fun()
---@field moveTask hs.task|nil
---@field moveTimer hs.timer.delayed|nil
---@field windowFilter hs.window.filter|nil
---@field init fun()
local mod = {}

mod.name = 'Brave Browser'

--- Tab titles that only work in Google Chrome, so their tabs are moved there.
mod.chromeOnlyTitles = { 'Remediation page' }

--- URL prefixes that only work in Google Chrome, so their tabs are moved there.
mod.chromeOnlyUrlPrefixes = { 'https://access.workspace.google.com/remediate' }

--- URL prefixes of tabs moved to the Google Meet app.
mod.meetUrlPrefixes = { 'https://meet.google.com/' }

--- Seconds without Brave window changes before the tabs are moved, titles change several times while a page loads.
mod.moveDelay = 0.5

mod.tab = { slack = ' Alloy Slack', mail = { work = 'Alloy, Inc. Mail', personal = 'jmartin.ca Mail' } }

---@return boolean
local function openSlack()
  return mod.activateTab(mod.tab.slack)()
end

local signInLabels = { '^sign ?in$', '^log ?in$' }

---@param element hs.axuielement
---@return boolean
local function isSignInButton(element)
  if element:attributeValue('AXRole') ~= 'AXButton' then
    return false
  end
  for _, attribute in ipairs({ 'AXTitle', 'AXDescription' }) do
    local label = element:attributeValue(attribute)
    if type(label) == 'string' then
      label = label:lower():match('^%s*(.-)%s*$')
      for _, pattern in ipairs(signInLabels) do
        if label:match(pattern) then
          return true
        end
      end
    end
  end
  return false
end

--- Opens the Slack quick switcher of the Slack tab.
function mod.slackQuickSwitcher()
  if not openSlack() then
    return
  end
  utils.wait(2)
  hs.eventtap.keyStroke({ 'cmd' }, 'k')
end

--- Returns a callback reacting to the hovered Slack message with the first emoji matching `chars`.
---@param chars string
---@return function
function mod.slackReactionEmoji(chars)
  return function()
    hs.eventtap.keyStroke({ 'cmd', 'shift' }, '\\')
    utils.wait()
    hs.eventtap.keyStrokes(chars)
    utils.wait(20)
    hs.eventtap.keyStroke({}, 'return')
  end
end

--- Opens the unread messages of the Slack tab.
function mod.slackUnread()
  if not openSlack() then
    return
  end
  utils.wait()
  hs.eventtap.keyStroke({ 'cmd', 'shift' }, 'a')
end

--- Opens the tab search.
function mod.openOmni()
  utils.switchToAndType(mod.name, { 'shift' }, 'o')
end

--- Presses the "Sign in" or "Log in" button of the focused Brave window, for forms that ignore the return key.
function mod.clickSignIn()
  local app = hs.application.get(mod.name)
  local window = app and app:focusedWindow()
  if not window then
    logger.w('No focused Brave window to sign in from.')
    return
  end

  utils.enableManualAccessibility(app)

  hs.axuielement.windowElement(window):elementSearch(function(message, results)
    if not results or #results == 0 then
      logger.wf('No sign in button found in "%s": %s', window:title(), message)
      return
    end
    results[1]:performAction('AXPress')
  end, isSignInButton, { count = 1 })
end

--- Returns a callback activating the first tab whose title contains `name`. The callback returns false, without
--- activating Brave, when Brave is not responding, or when it is not frontmost in time.
---@param name string
---@return fun(): boolean
function mod.activateTab(name)
  return function()
    if not appGuard.ensureResponsive(mod.name) then
      return false
    end
    jxa.run([[
      var browser = Application(']] .. mod.name .. [[');
      browser.activate();
      var wins = browser.windows;

      // loop tabs to find a web page with a title of <name>
      function main() {
        for (var i = 0; i < wins.length; i++) {
          var win = wins.at(i);
          var tabs = win.tabs;
          for (var j = 0; j < tabs.length; j++) {
            var tab = tabs.at(j);
            tab.title(); j;
            if (tab.title().indexOf(']] .. name .. [[') > -1) {
              win.activeTabIndex = j + 1;
              return;
            }
          }
        }
      }

      main();
    ]])
    if not appGuard.waitUntilFrontmost(mod.name, config.appLaunchTimeout) then
      return false
    end
    ---@type hs.window|nil
    local window = hs.window.find(name)
    if window then
      window:focus()
    end
    return true
  end
end

--- Returns the title and URL of the active tab.
---@return table<string, any>|nil
function mod.context()
  return chromium.context(mod.name)
end

--- Opens the URL of the active tab in Safari.
function mod.openActiveTabInSafari()
  chromium.openActiveTab(mod.name, function(url)
    hs.urlevent.openURLWithBundle(url, 'com.apple.Safari')
  end)
end

--- Opens the URL of the active tab in Google Chrome.
function mod.openActiveTabInChrome()
  chromium.openActiveTab(mod.name, googleChrome.openUrl)
end

---@class BraveTabMatcher
---@field titles string[] Title substrings.
---@field urlPrefixes string[]

--- Closes every Brave tab matched by one of `matchers`, then calls `callback` with the URLs of the closed tabs by
--- matcher name, or nil when they could not be read.
---@param matchers table<string, BraveTabMatcher>
---@param callback fun(closed: table<string, string[]>|nil)
---@return hs.task
local function closeTabs(matchers, callback)
  return jxa.start([[
    var matchers = ]] .. hs.json.encode(matchers) .. [[;
    var names = Object.keys(matchers);
    var brave = Application(']] .. mod.name .. [[');
    var closed = {};
    names.forEach(function(name) { closed[name] = []; });

    function matching(title, url) {
      return names.find(function(name) {
        var matcher = matchers[name];
        return matcher.titles.some(function(t) { return title.indexOf(t) > -1; })
          || matcher.urlPrefixes.some(function(prefix) { return url.indexOf(prefix) === 0; });
      });
    }

    brave.windows().forEach(function(win) {
      var tabTitles = win.tabs.title();
      var tabUrls = win.tabs.url();
      for (var i = tabUrls.length - 1; i >= 0; i--) {
        var name = matching(tabTitles[i], tabUrls[i]);
        if (name) {
          closed[name].unshift(tabUrls[i]);
          win.tabs[i].close();
        }
      }
    });

    closed;
  ]], function(ok, closed)
    if not ok or type(closed) ~= 'table' then
      logger.e('Could not get the URLs of the Brave tabs.')
      callback(nil)
      return
    end
    callback(closed)
  end)
end

--- Closes the Brave tabs matching `mod.chromeOnlyTitles` or `mod.chromeOnlyUrlPrefixes`, and opens them in Google
--- Chrome, and those matching `mod.meetUrlPrefixes`, and opens them in the Google Meet app. Runs in the background, and
--- is retried after `mod.moveDelay` seconds when the previous run is still going, so tabs are never closed twice.
function mod.moveTabs()
  if mod.moveTask and mod.moveTask:isRunning() then
    mod.moveTimer:start()
    return
  end
  mod.moveTask = closeTabs({
    chrome = { titles = mod.chromeOnlyTitles, urlPrefixes = mod.chromeOnlyUrlPrefixes },
    meet = { titles = {}, urlPrefixes = mod.meetUrlPrefixes },
  }, function(closed)
    if not closed then
      return
    end
    for _, url in ipairs(closed.chrome or {}) do
      logger.i('Moving to Google Chrome: ' .. url)
      googleChrome.openUrl(url)
    end
    for _, url in ipairs(closed.meet or {}) do
      logger.i('Moving to Google Meet: ' .. url)
      googleMeet.openUrl(url)
    end
  end)
end

--- Moves the tabs with `mod.moveTabs`, `mod.moveDelay` seconds after the last Brave window is created or title changes.
function mod.init()
  mod.moveTimer = hs.timer.delayed.new(mod.moveDelay, mod.moveTabs)
  local function scheduleMoveTabs()
    mod.moveTimer:start()
  end
  mod.windowFilter = hs.window.filter.new(mod.name)
  mod.windowFilter:subscribe(hs.window.filter.windowCreated, scheduleMoveTabs)
  mod.windowFilter:subscribe(hs.window.filter.windowTitleChanged, scheduleMoveTabs)
end

return mod
