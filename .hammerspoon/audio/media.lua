-- Toggles media playback across apps: macOS Now Playing (MediaRemote, through `media-control`), Music, Spotify and
-- every Brave tab, since the Now Playing session only controls the most recent player.
local logger = hs and hs.logger.new('media', 'info')
local jxa = require 'utils/jxa'

---@class NowPlaying
---@field playing boolean|nil
---@field bundleIdentifier string|nil
---@field title string|nil

---@class BraveMediaResult
---@field count number Media elements paused or played.
---@field error string|nil Set when Brave refuses to run JavaScript from Apple Events.

--- A paused player: `nowPlaying` is any other app paused through the Now Playing session.
---@alias MediaSource 'music'|'spotify'|'brave'|'nowPlaying'

---@class MediaModule
---@field braveName string
---@field braveBundleID string
---@field nativeBundleIDs table<string, MediaSource>
---@field lastPaused MediaSource[] Players paused by the last pause, resumed by the next toggle.
---@field lastPauseID string Marks the Brave media elements paused by the last pause.
---@field mediaKeyTap hs.eventtap|nil
---@field resumeChoice fun(paused: MediaSource[]): MediaSource|nil
---@field pauseAll fun(callback: fun(paused: MediaSource[], current: NowPlaying|nil)|nil)
---@field toggle fun()
---@field init fun()
local mod = {}

mod.braveName = 'Brave Browser'
mod.braveBundleID = 'com.brave.Browser'
mod.nativeBundleIDs = { ['com.apple.Music'] = 'music', ['com.spotify.client'] = 'spotify' }
mod.lastPaused = {}
mod.lastPauseID = ''

---@type MediaSource[]
local resumePriority = { 'nowPlaying', 'brave', 'spotify', 'music' }

-- Marks the paused elements with the id of the pause, so a resume only plays those.
---@param id string
---@return string
local function pauseJs(id)
  return [[(function () {
  var count = 0;
  document.querySelectorAll('video, audio').forEach(function (media) {
    if (!media.paused) { media.pause(); media.dataset.hammerspoonPaused = ']] .. id .. [['; count++; }
  });
  return count;
})()]]
end

---@param id string
---@return string
local function playJs(id)
  return [[(function () {
  var count = 0;
  document.querySelectorAll('video, audio').forEach(function (media) {
    if (media.dataset.hammerspoonPaused === ']] .. id .. [[') { media.play(); count++; }
  });
  return count;
})()]]
end

--- Returns the player to resume from those paused by the last pause: the only one, or with several, the first one
--- that is not Music by `resumePriority`. Returns nil when nothing was paused.
---@param paused MediaSource[]
---@return MediaSource|nil
function mod.resumeChoice(paused)
  ---@type table<string, boolean>
  local set = {}
  for _, source in ipairs(paused) do
    set[source] = true
  end
  for _, source in ipairs(resumePriority) do
    if set[source] then
      return source
    end
  end
  return nil
end

--- Decodes the JSON printed by `media-control get`, or returns nil when it failed or nothing is playing.
---@param ok boolean
---@param output string
---@return NowPlaying|nil
local function decodeNowPlaying(ok, output)
  if not ok then
    return nil
  end
  local decoded, value = pcall(hs.json.decode, output)
  if not decoded or type(value) ~= 'table' then
    return nil
  end
  return value
end

---@param command string
---@return string output
---@return boolean ok
local function mediaControl(command)
  local process = require 'utils/process'
  local output, status = process.execute('media-control ' .. command .. ' 2>&1')
  if status ~= true then
    logger.ef('media-control %s failed: %s', command, output)
  end
  return output, status == true
end

---@return NowPlaying|nil
local function nowPlaying()
  local output, ok = mediaControl('get')
  return decodeNowPlaying(ok, output)
end

--- Pauses Music and Spotify when they are running and playing, without launching them.
---@return MediaSource[] paused
local function pauseNativePlayers()
  ---@type MediaSource[]
  local paused = {}
  if hs.itunes.isRunning() and hs.itunes.isPlaying() then
    hs.itunes.pause()
    table.insert(paused, 'music')
  end
  if hs.spotify.isRunning() and hs.spotify.isPlaying() then
    hs.spotify.pause()
    table.insert(paused, 'spotify')
  end
  return paused
end

--- Returns a JXA script running `js` in every Brave tab, and returning a `BraveMediaResult` with the sum of the counts.
---@param js string
---@return string
local function braveScript(js)
  return [[
    var brave = Application(']] .. mod.braveName .. [[');
    var js = ]] .. jxa.jsString(js) .. [[;

    function main() {
      var result = { count: 0, error: null };
      var wins = brave.windows();
      for (var w = 0; w < wins.length; w++) {
        var tabs = wins[w].tabs();
        for (var t = 0; t < tabs.length; t++) {
          try {
            result.count += tabs[t].execute({ javascript: js }) || 0;
          } catch (e) {
            result.error = String(e);
            if (result.error.indexOf('turned off') > -1) {
              return result;
            }
          }
        }
      }
      return result;
    }

    main();
  ]]
end

--- Runs `js` in every Brave tab in the background, then calls `callback` with the result, or nil when Brave is not
--- running or refuses to run JavaScript.
---@param js string
---@param callback fun(result: BraveMediaResult|nil)
local function runInBrave(js, callback)
  if not hs.application.get(mod.braveBundleID) then
    callback(nil)
    return
  end
  jxa.start(braveScript(js), function(ok, result)
    ---@cast result BraveMediaResult|nil
    if not ok or type(result) ~= 'table' then
      callback(nil)
      return
    end
    if result.error and result.error:find('turned off', 1, true) then
      hs.alert.show('Enable Brave: View > Developer > Allow JavaScript from Apple Events')
      callback(nil)
      return
    end
    callback(result)
  end)
end

---@type string|nil
local statusAlert = nil

--- Shows `message`, replacing the previous status alert.
---@param message string
local function showStatus(message)
  if statusAlert then
    hs.alert.closeSpecific(statusAlert)
  end
  statusAlert = hs.alert.show(message)
end

---@type table<MediaSource, string>
local sourceNames = { music = 'Music', spotify = 'Spotify', brave = 'Brave', nowPlaying = 'Now Playing' }

--- Resumes `source`, or without one, the Now Playing session, or Music when there is none.
---@param source MediaSource|nil
---@param current NowPlaying|nil
local function resume(source, current)
  if not source then
    source = (current and current.bundleIdentifier) and 'nowPlaying' or 'music'
  end
  if source == 'music' then
    hs.itunes.play()
  elseif source == 'spotify' then
    hs.spotify.play()
  elseif source == 'brave' then
    runInBrave(playJs(mod.lastPauseID), function() end)
  else
    mediaControl('play')
  end
  showStatus('Play: ' .. sourceNames[source])
end

--- Pauses everything playing: every Brave tab, the Now Playing session, Music and Spotify, remembers what was
--- paused, then calls `callback` with it, and the Now Playing information from before the pause.
---@param callback fun(paused: MediaSource[], current: NowPlaying|nil)|nil
function mod.pauseAll(callback)
  local current = nowPlaying()
  local pauseID = tostring(math.floor(hs.timer.secondsSinceEpoch() * 1000))
  runInBrave(pauseJs(pauseID), function(brave)
    ---@type MediaSource[]
    local paused = {}
    if brave and brave.count > 0 then
      table.insert(paused, 'brave')
    end
    local bundleID = current and current.bundleIdentifier
    local handledElsewhere = mod.nativeBundleIDs[bundleID] or (bundleID == mod.braveBundleID and brave)
    if current and current.playing and not handledElsewhere then
      mediaControl('pause')
      table.insert(paused, 'nowPlaying')
    end
    for _, source in ipairs(pauseNativePlayers()) do
      table.insert(paused, source)
    end

    if #paused > 0 then
      mod.lastPaused = paused
      mod.lastPauseID = pauseID
      logger.i('Paused: ' .. table.concat(paused, ', '))
      showStatus('All Paused')
    end
    if callback then
      callback(paused, current)
    end
  end)
end

--- Pauses everything playing, see `mod.pauseAll`. When nothing was playing, resumes what the last pause paused, see
--- `mod.resumeChoice`.
local function toggle()
  mod.pauseAll(function(paused, current)
    if #paused == 0 then
      resume(mod.resumeChoice(mod.lastPaused), current)
    end
  end)
end

--- Shows an alert, then pauses or resumes media, see `toggle`.
function mod.toggle()
  showStatus('Pausing...')
  -- Lets the alert render before `media-control` blocks the main thread.
  hs.timer.doAfter(0.05, toggle)
end

--- Intercepts the play/pause media key to run `mod.toggle` instead.
function mod.init()
  mod.mediaKeyTap = hs.eventtap
    .new({ hs.eventtap.event.types.systemDefined }, function(event)
      local key = event:systemKey()
      if key.key ~= 'PLAY' then
        return false
      end
      if key.down and not key['repeat'] then
        hs.timer.doAfter(0, mod.toggle)
      end
      return true
    end)
    :start()
end

return mod
