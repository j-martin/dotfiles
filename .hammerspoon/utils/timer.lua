-- Measures elapsed time, e.g. `timer.start()` then `timer.alert('Config loaded')`.
---@class TimerModule
---@field start fun(clock: (fun(): number)|nil)
---@field elapsedSeconds fun(): number
---@field formatDuration fun(seconds: number): string
---@field message fun(text: string): string
---@field alert fun(text: string)
local mod = {}

---@type (fun(): number)|nil
local clock = nil
---@type number|nil
local startedAt = nil

--- Returns the current time in seconds using Hammerspoon's monotonic clock.
---@return number
local function defaultClock()
  return hs.timer.absoluteTime() / 1e9
end

--- Starts measuring. `now` returns the current time in seconds and defaults to Hammerspoon's monotonic clock.
---@param now (fun(): number)|nil
function mod.start(now)
  clock = now or defaultClock
  startedAt = clock()
end

--- Returns the seconds elapsed since `start` was called.
---@return number
function mod.elapsedSeconds()
  assert(clock and startedAt, 'timer.start() must be called before reading the elapsed time')
  return clock() - startedAt
end

--- Formats a duration as milliseconds under a second, otherwise as seconds with two decimals.
---@param seconds number
---@return string
function mod.formatDuration(seconds)
  if seconds < 1 then
    return string.format('%d ms', math.floor(seconds * 1000 + 0.5))
  end
  return string.format('%.2f s', seconds)
end

--- Returns `text` followed by the time elapsed since `start`, e.g. "Config loaded in 42 ms".
---@param text string
---@return string
function mod.message(text)
  return string.format('%s in %s', text, mod.formatDuration(mod.elapsedSeconds()))
end

--- Shows an `hs.alert` with `text` followed by the time elapsed since `start`.
---@param text string
function mod.alert(text)
  hs.alert.show(mod.message(text))
end

return mod
