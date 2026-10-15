local logger = hs.logger.new('slack', 'info')
local utils = require 'apps/utils'

local mod = {}

mod.name = 'Slack'
mod.bundleId = 'com.tinyspeck.slackmacgap'

-- Config example:
-- ~/.private/hammerspoon.json
-- {
--  "slackTeamMapping": {
--    "team1": "T00000000",
--    "team2": "T11111111"
--  }
--}

mod.teamMapping = {
  -- slack domain (with or without '.slack.com') = "teamId"
  -- example:
  afakecompany = "T00000000"
}

local prefixMapping = {
  C = 'channel',
  DA = 'user',
}

local function match(haystack, patternPrefix, pattern)
  local result = string.match(haystack, patternPrefix .. pattern)
  if not result then
    return nil
  end
  return result:sub(string.len(patternPrefix) + 1, -1)
end

--- Converts a https://<domain>.slack.com/archives/... URL to a slack:// deep link, or nil if it cannot be inferred.
-- e.g. https://xxxxxxxxx.slack.com/archives/C019DD3QJKY/p1639615885056700?thread_ts=1639615239.055000&cid=C019DD3QJKY
--   -> slack://channel?team=T00000000&id=C019DD3QJKY&message=1639615885.056700&thread_ts=1639615239.055000&cid=...
function mod.deepLink(url, encodedParams)
  local teamId = nil
  for domain, value in pairs(mod.teamMapping) do
    if url:match('^https://' .. domain .. '.*') then
      teamId = value
    end
  end

  local urlPrefix = nil
  local itemId = nil
  for key, value in pairs(prefixMapping) do
    itemId = match(url, 'slack.com/archives/', key .. '%w+')
    if itemId then
      urlPrefix = value
      break
    end
  end

  local messageId = match(url, '/p', '%d+')
  if messageId then
    messageId = messageId:sub(0, 10) .. '.' .. messageId:sub(11, -1)
  end

  logger.i(urlPrefix, teamId, itemId, messageId)
  if not urlPrefix or not teamId then
    return nil
  end
  return 'slack://' .. urlPrefix .. '?team=' .. teamId .. '&id=' .. itemId .. '&message=' .. (messageId or '') .. '&'
           .. encodedParams
end

-- e.g. "* Mike (DM) - Workspace - 2 new items - Slack" -> "Mike (DM) - Workspace"
local function cleanTitle(title)
  return (title:gsub('^%*%s*', ''):gsub('%s+%-%s+Slack$', ''):gsub('%s+%-%s+%d+ new items?$', ''))
end

--- Returns the current channel and its https://app.slack.com/client/<team>/<channel> URL.
function mod.context(window)
  utils.enableManualAccessibility(window:application())
  local webArea = utils.findElement(hs.axuielement.windowElement(window), utils.hasRole('AXWebArea'), 8)
  local url = webArea and webArea:attributeValue('AXURL')
  return {title = cleanTitle(window:title()), url = type(url) == 'table' and url.url or nil}
end

--- Loads the team mapping from ~/.private/hammerspoon.json.
function mod.init()
  local privateConfigPath = os.getenv('HOME') .. "/.private/hammerspoon.json"
  if hs.fs.attributes(privateConfigPath) then
    logger.f("Loading private config from '%s'...", privateConfigPath)
    mod.teamMapping = hs.json.read(privateConfigPath).slackTeamMapping or mod.teamMapping
  end
end

return mod
