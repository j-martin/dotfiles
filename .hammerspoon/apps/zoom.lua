---@class ZoomApp
---@field bundleId string
---@field deepLink fun(url: string, encodedParams: string): string
local mod = {}

mod.bundleId = 'us.zoom.xos'

--- Converts a https://xxxx.zoom.us/j/000000000000?pwd=... URL to a zoommtg:// deep link.
---@param url string
---@param encodedParams string
---@return string
function mod.deepLink(url, encodedParams)
  local meetingId = url:match('zoom.us/j/(%d+)')
  return 'zoommtg://zoom.us/join?confno=' .. (meetingId or '') .. '&' .. encodedParams
end

return mod
