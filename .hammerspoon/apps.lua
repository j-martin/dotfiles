local logger = hs.logger.new('apps', 'info')
local windows = require 'windows'

local mod = {}

function mod.getExecPath(exec)
  dirs = {'/opt/homebrew/bin/', '/usr/local/bin/', os.getenv("HOME") .. "/bin/" }
  for _, dir in ipairs(dirs) do
    local path=dir .. exec
    if hs.fs.attributes(path) then
      return path
    end
  end
  logger.i("Could not find executable in PATHs. Defaulting to executable's name.")
  return exec
end

local function isHost(hostname)
  for _, name in ipairs(hs.host.names()) do
    if string.match(name, hostname) then
      return true
    end
  end
  return false
end

local function getAppNameBasedOnHost(homeApp, workApp)
  if isHost('nmbp1423') then
    return workApp
  end
  return homeApp
end

mod.name = {
  activityMonitor = 'Activity Monitor',
  iTerm = 'iTerm2',
  idea = 'GoLand',
  ripcord = 'Ripcord',
}

-- Config example:
-- ~/.private/hammerspoon.json
-- {
--  "slackTeamMapping": {
--    "team1": "T00000000",
--    "team2": "T11111111"
--  }
--}

mod.slackTeamMapping = {
  -- slack domain (with or without '.slack.com') = "teamId"
  -- example:
  afakecompany = "T00000000"
}

local screenRatioNotch = 1125.0

local slackPrefixMapping = {
  C = 'channel',
  DA = 'user',
}

local function wait(n)
  local n = n or 1
  -- 0.01s
  hs.timer.usleep(10000 * n)
end

function mod.switchToAndType(application, modifiers, keyStroke, delay)
  windows.launchOrCycleFocus(application)()
  wait(delay)
  hs.eventtap.keyStroke(modifiers, keyStroke)
end

function mod.ideaOmni()
  mod.switchToAndType(mod.name.idea, {'cmd'}, 'o', 10)
end

function mod.iTermOmni()
  mod.switchToAndType(mod.name.iTerm, {'cmd'}, 'o')
end

function mod.ripcordQuickSwitcher()
  windows.launchOrCycleFocus(mod.name.ripcord)()
  wait(2)
  hs.eventtap.keyStroke({'cmd'}, 'k')
end

function mod.googleMeetToggleMute()
  hs.eventtap.keyStroke('cmd', 'd', 200, hs.application.get('Google Meet'))
end

local function clickNotification(offset_x, offset_y)
  local currentScreen = hs.mouse.getCurrentScreen()
  local currentPos = hs.mouse.getRelativePosition()
  local targetScreen = hs.screen.primaryScreen()
  local targetFrame = targetScreen:frame()

  if targetFrame.h == screenRatioNotch then
    offset_y = offset_y + 40
  end

  local targetPos = {x = targetFrame.w - offset_x, y = offset_y}

  hs.mouse.setRelativePosition(targetPos, targetScreen)
  wait(5)
  hs.eventtap.leftClick(targetPos)
  hs.mouse.setRelativePosition(currentPos, currentScreen)
end

function mod.openNotification()
  -- Use offset_y=40 if hiding menu bar
  clickNotification(120, 70)
end

function mod.closeNotification()
  -- Use offset_y=20 if hiding menu bar
  clickNotification(355, 50)
end

function mod.activityMonitor()
  mod.switchToAndType(mod.name.activityMonitor, {'cmd'}, '2')
  local win = hs.window.focusedWindow()
  local laptopScreen = 'Color LCD'

  win:moveToScreen(laptopScreen)
  win:moveToUnit({0.85, 0.9, 0.1, 0.1}, 0)
  hs.eventtap.keyStroke({'cmd'}, '1')
end

function match(haystack, patternPrefix, pattern)
  logger.i(haystack, patternPrefix, pattern)
  local result = string.match(haystack, patternPrefix .. pattern)
  if not result then
    return nil
  end
  return result:sub(string.len(patternPrefix) + 1, -1)
end

mod.lastUrl = nil

function mod.httpCallback(scheme, host, params, fullUrl, senderPID)
  logger.i(scheme, host, hs.inspect(params), fullUrl, senderPID)
  local bundleId = 'com.brave.Browser'
  local url = fullUrl
  if mod.lastUrl == fullUrl then
    logger.i("Same URL as before. Defaulting to Chrome...")
    mod.open(bundleId, fullUrl)
    return
  end

  mod.lastUrl = fullUrl

  local encodedParams = ''
  if next(params) then
    encodedParams = fullUrl:gsub('.*?', '')
  end

  if not host then
    logger.i("No host, assuming it is a file.")
    hs.urlevent.openURL(url:gsub('^http:[ab]/', 'file://'))
    return
  end

  if host:match('.*.zoom.us$') then
    bundleId = 'us.zoom.xos'
    -- https://xxxxxxxxxxxx.zoom.us/j/000000000000?pwd=OVVVeHlkYWoxS3FWRVRKTzZZcFVDdz09
    local meetingId = match(fullUrl,  'zoom.us/j/', '%d+')
    url = 'zoommtg://zoom.us/join?confno=' .. meetingId .. "&" .. encodedParams

  elseif fullUrl:match('https://.*.slack.com/archives/.*') then
    -- Notes:

    -- Initial URL
    -- https://xxxxxxxxx.slack.com/archives/C019DD3QJKY/p1639615885056700?thread_ts=1639615239.055000&cid=C019DD3QJKY --> Channel with thread
    -- Resulting URL:
    -- slack://channel?team=T00000000&id=C019DD3QJKY&message=1639615885.056700&thread_ts=1639615239.055000&host=slack.com

    -- https://xxxxxxxxx.slack.com/archives/DA324HC1E/p1639790053004200 --> DM with message
    -- https://xxxxxxxxx.slack.com/archives/G01C06HCLPR/p1640124144000100

    local teamId = nil

    for domain, value in pairs(mod.slackTeamMapping) do
      if fullUrl:match('^https://' .. domain .. '.*') then
        teamId = value
      end
    end

    local urlPrefix = nil
    local itemId = nil

    for key, value in pairs(slackPrefixMapping) do
      itemId = match(fullUrl, 'slack.com/archives/', key .. '%w+')
      if itemId then
        urlPrefix = value
        break
      end
    end

    local messageId = match(fullUrl, '/p', '%d+')
    if messageId then
       messageId = messageId:sub(0, 10) .. '.' .. messageId:sub(11, -1)
    end

    logger.i(urlPrefix, teamId, itemId, messageId)

    if urlPrefix and teamId then
      bundleId = 'com.tinyspeck.slackmacgap'
      url = 'slack://' .. urlPrefix .. '?team=' .. teamId .. '&id=' .. itemId .. '&message=' .. messageId .. '&' .. encodedParams
    else
      logger.w("Could not infer the 'slack://' from the URL. Defaulting to your browser redirect.")
    end
  end
  mod.open(bundleId, url)
end

function mod.open(bundleId, url)
  logger.i(bundleId, url)

  hs.application.launchOrFocusByBundleID(bundleId)
  hs.urlevent.openURLWithBundle(url, bundleId)
end

function mod.init()
  local privateConfigPath = os.getenv('HOME') .. "/.private/hammerspoon.json"
  local privateConfigFile = io.open(privateConfigPath)
  if privateConfigFile then
    logger.f("Loading private config from '%s'...", privateConfigPath)
    privateConfigFile:close()
    mod.slackTeamMapping = hs.json.read(privateConfigPath).slackTeamMapping
  end
  -- hs.urlevent.httpCallback = mod.httpCallback
  -- hs.urlevent.slackCallback = logger.i
  -- hs.urlevent.setDefaultHandler('http')
end


return mod
