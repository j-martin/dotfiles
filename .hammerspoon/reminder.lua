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
    local padding = '           '
    alert('\n' .. padding .. message .. padding .. '\n', duration or 10)
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
      timer.doAfter(counter, notice(item.name .. ' ▶', interval - 1))
      increment(interval)
      timer.doAfter(counter, notice('◀ ' .. item.name, interval - 1))
      increment(interval)
    end

    fnutils.each(action, setupTimer)
    timer.doAfter(counter, notice("✔"))
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
  { name = '✸' },
  { name = '✪' },
}

local reminders = {
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
  -- disabling reset for now
  -- watcher.new(parseEvent):start()
end

return mod
