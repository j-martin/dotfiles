local apps = require 'apps'
local logger = hs.logger.new('chrome', 'debug')

local mod = {}

mod.name = 'Brave Browser'

mod.tab = {slack = ' Alloy Slack', mail = {work = 'Alloy, Inc. Mail', personal = 'jmartin.ca Mail'}}

local function wait(n)
  local n = n or 1
  hs.timer.usleep(10000 * n)
end

function openSlack()
  mod.activateTab(mod.tab.slack)()
end

function mod.slackQuickSwitcher()
  openSlack()
  wait(2)
  hs.eventtap.keyStroke({'cmd'}, 'k')
end

function mod.slackReactionEmoji(chars)
  return function()
    hs.eventtap.keyStroke({'cmd', 'shift'}, '\\')
    wait()
    hs.eventtap.keyStrokes(chars)
    wait(20)
    hs.eventtap.keyStroke({}, 'return')
  end
end

function mod.slackUnread()
  openSlack()
  wait()
  hs.eventtap.keyStroke({'cmd', 'shift'}, 'a')
end

function mod.openOmni()
  apps.switchToAndType(mod.name, {'shift'}, 'o')
end

local signInLabels = {'^sign ?in$', '^log ?in$'}

local function isSignInButton(element)
  if element.AXRole ~= 'AXButton' then
    return false
  end
  for _, attribute in ipairs({'AXTitle', 'AXDescription'}) do
    local label = element[attribute]
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

-- Presses the "Sign in" or "Log in" button of the focused Brave window, for forms that ignore the return key.
function mod.clickSignIn()
  local app = hs.application.get(mod.name)
  local window = app and app:focusedWindow()
  if not window then
    logger.w('No focused Brave window to sign in from.')
    return
  end

  -- Chromium only exposes the web page accessibility tree once asked to.
  hs.axuielement.applicationElement(app):setAttributeValue('AXManualAccessibility', true)

  hs.axuielement.windowElement(window):elementSearch(function(message, results)
    if not results or #results == 0 then
      logger.wf('No sign in button found in "%s": %s', window:title(), message)
      return
    end
    results[1]:performAction('AXPress')
  end, isSignInButton, {count = 1})
end

function mod.activateTab(name)
  return function()
    hs.osascript.javascript([[
      var chrome = Application('Brave Browser');
      chrome.activate();
      var wins = chrome.windows;

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

return mod
