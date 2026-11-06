local logger = hs.logger.new('brave', 'debug')
local utils = require 'apps/utils'
local chromium = require 'apps/chromium'
local googleChrome = require 'apps/google_chrome'
local googleMeet = require 'apps/google_meet'
local appGuard = require 'utils/app_guard'
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
---@field moveChromeOnlyTabsToChrome fun()
---@field meetUrlPrefixes string[]
---@field moveMeetTabsToGoogleMeet fun()
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
    hs.osascript.javascript([[
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

--- Closes every Brave tab whose title contains one of `titles` or whose URL starts with one of `urlPrefixes`.
---@param titles string[]
---@param urlPrefixes string[]
---@return string[]|nil urls of the closed tabs, nil when they could not be read
local function closeTabs(titles, urlPrefixes)
  local ok, urls = hs.osascript.javascript([[
    var titles = ]] .. hs.json.encode(titles) .. [[;
    var urlPrefixes = ]] .. hs.json.encode(urlPrefixes) .. [[;
    var brave = Application(']] .. mod.name .. [[');
    var urls = [];

    function matches(title, url) {
      return titles.some(function(t) { return title.indexOf(t) > -1; })
        || urlPrefixes.some(function(prefix) { return url.indexOf(prefix) === 0; });
    }

    brave.windows().forEach(function(win) {
      var tabTitles = win.tabs.title();
      var tabUrls = win.tabs.url();
      for (var i = tabUrls.length - 1; i >= 0; i--) {
        if (matches(tabTitles[i], tabUrls[i])) {
          urls.unshift(tabUrls[i]);
          win.tabs[i].close();
        }
      }
    });

    urls;
  ]])
  if not ok or type(urls) ~= 'table' then
    logger.e('Could not get the URLs of the Brave tabs.')
    return nil
  end
  ---@cast urls string[]
  return urls
end

--- Closes every Brave tab matching `mod.chromeOnlyTitles` or `mod.chromeOnlyUrlPrefixes`, and opens them in Google Chrome.
function mod.moveChromeOnlyTabsToChrome()
  for _, url in ipairs(closeTabs(mod.chromeOnlyTitles, mod.chromeOnlyUrlPrefixes) or {}) do
    logger.i('Moving to Google Chrome: ' .. url)
    googleChrome.openUrl(url)
  end
end

--- Closes every Brave tab matching `mod.meetUrlPrefixes`, and opens them in the Google Meet app.
function mod.moveMeetTabsToGoogleMeet()
  for _, url in ipairs(closeTabs({}, mod.meetUrlPrefixes) or {}) do
    logger.i('Moving to Google Meet: ' .. url)
    googleMeet.openUrl(url)
  end
end

local function moveTabs()
  mod.moveChromeOnlyTabsToChrome()
  mod.moveMeetTabsToGoogleMeet()
end

--- Moves Chrome only Brave tabs to Google Chrome, and Meet tabs to Google Meet, whenever a Brave window title changes.
function mod.init()
  mod.windowFilter = hs.window.filter.new(mod.name)
  mod.windowFilter:subscribe(hs.window.filter.windowCreated, moveTabs)
  mod.windowFilter:subscribe(hs.window.filter.windowTitleChanged, moveTabs)
end

return mod
