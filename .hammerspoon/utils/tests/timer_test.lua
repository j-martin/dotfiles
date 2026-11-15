local timer = require 'utils/timer'

---@type table<string, fun()>
local cases = {}

--- Returns a fake clock yielding the given times in order.
---@param times number[]
---@return fun(): number
local function fakeClock(times)
  ---@type integer
  local index = 0
  return function()
    index = index + 1
    return times[index]
  end
end

function cases.formatDurationUsesMillisecondsUnderOneSecond()
  assert(timer.formatDuration(0.2346) == '235 ms', timer.formatDuration(0.2346))
end

function cases.formatDurationUsesSecondsFromOneSecond()
  assert(timer.formatDuration(1.234) == '1.23 s', timer.formatDuration(1.234))
end

function cases.elapsedSecondsMeasuresFromStart()
  timer.start(fakeClock({ 10, 10.5 }))
  local elapsed = timer.elapsedSeconds()
  assert(elapsed == 0.5, tostring(elapsed))
end

function cases.messageIncludesElapsedTime()
  timer.start(fakeClock({ 3, 3.042 }))
  local message = timer.message('Config loaded')
  assert(message == 'Config loaded in 42 ms', message)
end

return cases
