local logger = hs.logger.new('google_meet', 'info')

---@class GoogleMeetApp
---@field name string
---@field appId string
---@field chromeBundleId string
---@field toggleMute fun()
---@field isMeetUrl fun(url: string): boolean
---@field openUrl fun(url: string)
local mod = {}

mod.name = 'Google Meet'

--- Chrome app id of the Google Meet PWA.
mod.appId = 'kjgfgldnnfoeklkmfkjfagphfepbbdan'

mod.chromeBundleId = 'com.google.Chrome'

--- Toggles the microphone, even when Google Meet is not focused.
function mod.toggleMute()
  hs.eventtap.keyStroke('cmd', 'd', 200, hs.application.get(mod.name))
end

--- Returns true when `url` is a Google Meet URL.
---@param url string
---@return boolean
function mod.isMeetUrl(url)
  ---@type string|nil
  local host = url:match('^https?://([^/?#:]+)')
  return host ~= nil and host:lower() == 'meet.google.com'
end

--- Opens `url` in the Google Meet app. Opening the URL with the app bundle would drop it and show the Meet home page,
--- so Google Chrome is asked to launch the app at `url` instead.
---@param url string
function mod.openUrl(url)
  ---@type string|nil
  local chromePath = hs.application.pathForBundleID(mod.chromeBundleId)
  if not chromePath then
    logger.e('Google Chrome is not installed, cannot open in Google Meet: ' .. url)
    return
  end
  hs.task
    .new(chromePath .. '/Contents/MacOS/Google Chrome', nil, {
      '--app-id=' .. mod.appId,
      '--app-launch-url-for-shortcuts-menu-item=' .. url,
    })
    :start()
end

return mod
