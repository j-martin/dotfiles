local logger = hs.logger.new('brave', 'debug')
local utils = require 'apps/utils'

---@class BraveApp
---@field name string
---@field tab table<string, string|table<string, string>>
---@field slackQuickSwitcher fun()
---@field slackReactionEmoji fun(chars: string): function
---@field slackUnread fun()
---@field openOmni fun()
---@field clickSignIn fun()
---@field activateTab fun(name: string): function
---@field context fun(): table<string, any>|nil
---@field openActiveTabInSafari fun()
local mod = {}

mod.name = 'Brave Browser'

mod.tab = { slack = ' Alloy Slack', mail = { work = 'Alloy, Inc. Mail', personal = 'jmartin.ca Mail' } }

---@return nil
local function openSlack()
  mod.activateTab(mod.tab.slack)()
end

---@param element hs.axuielement|nil
---@return boolean
local function isSignInButton(element)
  local role = element and element:attributeValue('AXRole')
  local title = element and element:attributeValue('AXTitle')
  return role == 'AXButton' and type(title) == 'string' and title:match('Sign in|Log in') ~= nil
end

--- Opens the Slack quick switcher of the Slack tab.
function mod.slackQuickSwitcher()
  openSlack()
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
  openSlack()
  utils.wait()
  hs.eventtap.keyStroke({ 'cmd', 'shift' }, 'a')
end

--- Opens the tab search.
function mod.openOmni()
  -- implementation retained from existing module behavior.
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

--- Returns a callback activating the first tab whose title contains `name`.
---@param name string
---@return function
function mod.activateTab(name)
  return function()
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
    hs.window.find(name):focus()
  end
end

--- Returns the title and URL of the active tab.
---@return table<string, any>|nil
function mod.context()
  local ok, tab =
    hs.osascript.javascript("const t = Application('" .. mod.name .. "').windows[0].activeTab(); [t.title(), t.url()]")
  if not ok or type(tab) ~= 'table' then
    return nil
  end
  return { title = tab[1], url = tab[2] }
end

--- Opens the URL of the active tab in Safari.
function mod.openActiveTabInSafari()
  local tab = mod.context()
  if not tab then
    logger.e('Could not get the URL of the active Brave tab.')
    return
  end
  hs.urlevent.openURLWithBundle(tab.url, 'com.apple.Safari')
end

return mod
