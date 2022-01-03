local eventtap = require 'hs.eventtap'
local json = require 'hs.json'
local logger = hs.logger.new('apps', 'info')
local mouse = require 'hs.mouse'
local screen = require 'hs.screen'
local timer = require 'hs.timer'
local urlevent = require 'hs.urlevent'
local window = require 'hs.window'
local windows = require 'windows'

local mod = {}

mod.name = {
  activityMonitor = 'Activity Monitor',
  iTerm = 'iTerm2',
  idea = 'IntelliJ IDEA',
  noisyTyper = 'NoisyTyper',
  ripcord = 'Ripcord',
}

mod.slackTeamMapping = {
  -- subdomain (without .slack.com) = "teamId"
  -- example:
  fakecompany = "T00000000"
}

local slackPrefixMapping = {
  C = 'channel',
  DA = 'user',
}

local states = {noisyTyperEnabled = false}

local function wait(n)
  local n = n or 1
  -- 0.01s
  timer.usleep(10000 * n)
end

function mod.switchToAndType(application, modifiers, keyStroke, delay)
  windows.launchOrCycleFocus(application)()
  wait(delay)
  eventtap.keyStroke(modifiers, keyStroke)
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
  eventtap.keyStroke({'cmd'}, 'k')
end

local function clickNotification(offset_x, offset_y)
  local currentScreen = mouse.getCurrentScreen()
  local currentPos = mouse.getRelativePosition()
  local targetScreen = screen.primaryScreen()
  local targetPos = {x = targetScreen:frame().w - offset_x, y = offset_y}

  mouse.setRelativePosition(targetPos, targetScreen)
  wait(5)
  eventtap.leftClick(targetPos)
  mouse.setRelativePosition(currentPos, currentScreen)
end

function mod.openNotification()
  -- Use y=40 if hiding menu bar
  clickNotification(120, 70)
end

function mod.closeNotification()
  -- Use y=20 if hiding menu bar
  clickNotification(355, 50)
end

function mod.activityMonitor()
  mod.switchToAndType(mod.name.activityMonitor, {'cmd'}, '2')
  local win = hs.window.focusedWindow()
  local laptopScreen = 'Color LCD'

  win:moveToScreen(laptopScreen)
  win:moveToUnit({0.85, 0.9, 0.1, 0.1}, 0)
  eventtap.keyStroke({'cmd'}, '1')
end

function match(haystack, patternPrefix, pattern)
  logger.i(haystack, patternPrefix, pattern)
  local result = string.match(haystack, patternPrefix .. pattern)
  if not result then
    return nil
  end
  return result:sub(string.len(patternPrefix) + 1, -1)
end

function mod.httpCallback(scheme, host, params, fullUrl, senderPID)
  logger.i(scheme, host, hs.inspect(params), fullUrl, senderPID)
  local url = fullUrl
  local bundleId = 'com.google.Chrome'

  local encodedParams = ''
  if next(params) then
    encodedParams = fullUrl:gsub('.*?', '')
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

    for key, value in pairs(mod.slackTeamMapping) do
      if fullUrl:match('^https://' .. key .. '.*') then
        teamId = value
      end
    end

    local prefix = nil
    local id = nil

    for key, value in pairs(slackPrefixMapping) do
      id = match(fullUrl, 'slack.com/archives/', key .. '%w+')
      if id then
        prefix = value
        break
      end
    end

    local messageId = match(fullUrl, '/p', '%d+')
    if messageId then
       messageId = messageId:sub(0, 10) .. '.' .. messageId:sub(11, -1)
    end

    logger.i(prefix, teamId, id, messageId)

    if prefix and teamId then
      bundleId = 'com.tinyspeck.slackmacgap'
      url = 'slack://' .. prefix .. '?team=' .. teamId .. '&id=' .. id .. '&message=' .. messageId .. '&' .. encodedParams
    else
      logger.w("Could not infer the 'slack://' from the URL. Defaulting to your browser redirect.")
    end
  end

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
    mod.slackTeamMapping = json.read(privateConfigPath).slackTeamMapping
  end
  hs.urlevent.httpCallback = mod.httpCallback
  hs.urlevent.slackCallback = logger.i
  hs.urlevent.setDefaultHandler('http')
end


return mod
