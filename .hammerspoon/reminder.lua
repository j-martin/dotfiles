local timer = require "hs.timer"
local alert = require "hs.alert"
local fnutils = require "hs.fnutils"
local watcher = require "hs.caffeinate.watcher"
local logger = require "hs.logger"
local sound = require "hs.sound"
local log = logger.new('reminder', 'debug')

local mod = {}

local isAwake = {
  watcher.screensaverDidStop,
  watcher.sessionDidBecomeActive,
  watcher.systemDidWake,
  watcher.screensDidUnlock
}

-- System Sounds
-- {
--   "Basso", "Blow", "Bottle", "Frog",
--   "Funk", "Glass", "Hero", "Morse", "Ping",
--   "Pop", "Purr", "Sosumi", "Submarine", "Tink"
-- }

local function notice(message, duration)
  return function()
    alert(message, duration or 10)
    sound.getByName("Hero"):play()
    sound.getByName("Purr"):play()
  end
end

local function noticeActions(action)
  return function ()
    local counter = 0
    local defaultInterval = 30

    local function increment(interval)
      counter = counter + interval
    end

    local function setupTimer(item)
      local interval = item.interval or defaultInterval
      timer.doAfter(counter, notice(item.name .. 'R', interval / 2))
      increment(interval)
      timer.doAfter(counter, notice(item.name .. 'L', interval / 2))
      increment(interval)
    end

    fnutils.each(action, setupTimer)
    timer.doAfter(counter, notice('Done!'))
    timer.doAfter(counter + 1, notice('Done!'))
  end
end

local function setReminder(item)
  if not item.timer then
    item.timer = timer.doEvery(item.freq, item.fn or notice(item.name))
  end
  item.timer:stop():start()
end

local function setReminders(reminders)
  fnutils.each(reminders, setReminder)
end


local stretchesList = {
  { name = 'HS' },
  { name = 'HTRS' },
  { name = 'HTLS' },
}

local reminders = {
  { name = 'P', freq = 600 },
  { name = 'P.Done.', freq = 660 },
  { name = 'Break', freq = 1800, fn = noticeActions(stretchesList) }
}

local function parseEvent(event)
  if fnutils.contains(isAwake, event) then setReminders(reminders) end
end

mod.stretches = noticeActions(stretchesList)

function mod.reset()
  alert("Resetting timers")
  setReminders(reminders)
end

function mod.init()
  setReminders(reminders)
  watcher.new(parseEvent):start()
end

return mod
