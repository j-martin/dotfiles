local logger = hs.logger.new('google_chrome', 'info')
local chromium = require 'apps/chromium'

---@class GoogleChromeApp
---@field name string
---@field bundleId string
---@field chromeOnlyHosts string[]
---@field keptHosts table<string, boolean>
---@field context fun(): table<string, string>|nil
---@field openUrl fun(url: string)
---@field openActiveTabInDefaultBrowser fun()
---@field moveTabsToDefaultBrowser fun()
---@field onApplicationEvent fun(event: number)
---@field init fun()
local mod = {}

mod.name = 'Google Chrome'
mod.bundleId = 'com.google.Chrome'

--- Hosts, including their subdomains, that cannot be opened in the default browser, so their tabs stay in Google Chrome.
mod.chromeOnlyHosts = {
  'google.com',
}

--- Hosts explicitly opened in Google Chrome with `mod.openUrl`, kept in Google Chrome until Hammerspoon reloads.
mod.keptHosts = {}

--- Returns the title and URL of the active tab.
---@return table<string, string>|nil
function mod.context()
  return chromium.context(mod.name)
end

--- Opens `url` in Google Chrome, and keeps its host there instead of moving it to the default browser.
---@param url string
function mod.openUrl(url)
  ---@type string|nil
  local host = url:match('^https?://([^/?#:]+)')
  if host then
    mod.keptHosts[host:lower()] = true
  end
  hs.urlevent.openURLWithBundle(url, mod.bundleId)
end

--- Opens the URL of the active tab in the default browser.
function mod.openActiveTabInDefaultBrowser()
  local browserBundleId = hs.urlevent.getDefaultHandler('http')
  if not browserBundleId or browserBundleId:lower() == mod.bundleId:lower() then
    logger.wf("Default browser is '%s', not opening the Google Chrome tab.", browserBundleId)
    return
  end

  chromium.openActiveTab(mod.name, function(url)
    hs.urlevent.openURLWithBundle(url, browserBundleId)
  end)
end

--- Moves every http(s) Google Chrome tab, across all windows, to the default browser, except tabs on
--- `mod.chromeOnlyHosts` and `mod.keptHosts`.
function mod.moveTabsToDefaultBrowser()
  local browserBundleId = hs.urlevent.getDefaultHandler('http')
  if not browserBundleId or browserBundleId:lower() == mod.bundleId:lower() then
    logger.wf("Default browser is '%s', not moving Google Chrome tabs.", browserBundleId)
    return
  end

  ---@type string[]
  local stayingHosts = { table.unpack(mod.chromeOnlyHosts) }
  for host in pairs(mod.keptHosts) do
    table.insert(stayingHosts, host)
  end

  local ok, urls = hs.osascript.javascript([[
    var chromeOnlyHosts = ]] .. hs.json.encode(stayingHosts) .. [[;
    var chrome = Application('Google Chrome');
    var urls = [];

    function shouldStayInChrome(url) {
      var match = url.match(/^https?:\/\/([^\/?#:]+)/i);
      if (match === null) {
        return true;
      }
      var host = match[1].toLowerCase();
      return chromeOnlyHosts.some(function(chromeOnlyHost) {
        return host === chromeOnlyHost || host.endsWith('.' + chromeOnlyHost);
      });
    }

    chrome.windows().reverse().forEach(function(win) {
      var tabUrls = win.tabs.url();
      var moved = [];
      for (var i = tabUrls.length - 1; i >= 0; i--) {
        if (!shouldStayInChrome(tabUrls[i])) {
          moved.unshift(tabUrls[i]);
          win.tabs[i].close();
        }
      }
      urls = moved.concat(urls);
    });

    urls;
  ]])
  if not ok or type(urls) ~= 'table' then
    logger.e('Could not get the URLs of the Google Chrome tabs.')
    return
  end
  if #urls == 0 then
    logger.i('No Google Chrome tabs to move to the default browser.')
    return
  end

  hs.pasteboard.setContents(table.concat(urls, '\n'))
  hs.application.launchOrFocusByBundleID(browserBundleId)
  for _, url in ipairs(urls) do
    hs.urlevent.openURLWithBundle(url, browserBundleId)
  end
end

--- Moves the tabs to the default browser when Google Chrome is activated.
---@param event number
function mod.onApplicationEvent(event)
  if event == hs.application.watcher.activated then
    mod.moveTabsToDefaultBrowser()
  end
end

--- Moves Google Chrome tabs to the default browser whenever their title changes.
function mod.init()
  mod.windowFilter = hs.window.filter.new(mod.name)
  mod.windowFilter:subscribe(hs.window.filter.windowTitleChanged, function()
    mod.moveTabsToDefaultBrowser()
  end)
end

return mod
