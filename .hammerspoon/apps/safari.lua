local logger = hs.logger.new('safari', 'info')

local mod = {}

mod.name = 'Safari'

--- Returns the title and URL of the active tab.
function mod.context()
  local ok, tab =
    hs.osascript.javascript("const t = Application('" .. mod.name .. "').windows[0].currentTab(); [t.name(), t.url()]")
  if not ok or type(tab) ~= 'table' then
    return nil
  end
  return { title = tab[1], url = tab[2] }
end

--- Opens the URL of the active tab in the default browser.
function mod.openActiveTabInDefaultBrowser()
  local browserBundleId = hs.urlevent.getDefaultHandler('http')
  if not browserBundleId or browserBundleId:lower() == 'com.apple.safari' then
    logger.wf("Default browser is '%s', not opening the Safari tab.", browserBundleId)
    return
  end

  local tab = mod.context()
  if not tab then
    logger.e('Could not get the URL of the active Safari tab.')
    return
  end
  hs.urlevent.openURLWithBundle(tab.url, browserBundleId)
end

return mod
