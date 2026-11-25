local media = require 'audio/media'

---@type table<string, fun()>
local cases = {}

function cases.resumesTheOnlyPausedPlayer()
  assert(media.resumeChoice({ 'brave' }) == 'brave')
end

function cases.resumesMusicWhenItWasTheOnlyPausedPlayer()
  assert(media.resumeChoice({ 'music' }) == 'music')
end

function cases.resumesTheOtherPlayerWhenMusicWasPausedWithIt()
  assert(media.resumeChoice({ 'music', 'brave' }) == 'brave')
end

function cases.prefersTheNowPlayingSessionOverOtherPlayers()
  assert(media.resumeChoice({ 'brave', 'spotify', 'nowPlaying' }) == 'nowPlaying')
end

function cases.resumesNothingWhenNothingWasPaused()
  assert(media.resumeChoice({}) == nil)
end

return cases
