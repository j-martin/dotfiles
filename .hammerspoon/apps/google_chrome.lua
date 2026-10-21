local logger = hs.logger.new('google_chrome', 'info')

local mod = {}

mod.name = 'Google Chrome'

--- Hosts, including their subdomains, that cannot be opened in the default browser, so their tabs stay in Google Chrome.
mod.chromeOnlyHosts = {
  'google.com',
}

--- Moves every http(s) Google Chrome tab, across all windows, to the default browser, except tabs on `mod.chromeOnlyHosts`.
function mod.moveTabsToDefaultBrowser()
  local browserBundleId = hs.urlevent.getDefaultHandler('http')
  if not browserBundleId or browserBundleId:lower() == 'com.google.chrome' then
    logger.wf("Default browser is '%s', not moving Google Chrome tabs.", browserBundleId)
    return
  end

  local ok, urls = hs.osascript.javascript([[
    var chromeOnlyHosts = ]] .. hs.json.encode(mod.chromeOnlyHosts) .. [[;
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

    // Close in reverse so the remaining window and tab indexes stay valid.
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
function mod.onApplicationEvent(event)
  if event == hs.application.watcher.activated then
    mod.moveTabsToDefaultBrowser()
  end
end

--- Moves Google Chrome tabs to the default browser whenever their title changes.
function mod.init()
  -- Activation alone misses tabs opened while Chrome is already frontmost, e.g. a link clicked in Gmail.
  mod.windowFilter = hs.window.filter.new(mod.name)
  mod.windowFilter:subscribe(hs.window.filter.windowTitleChanged, function()
    mod.moveTabsToDefaultBrowser()
  end)
end

return mod
