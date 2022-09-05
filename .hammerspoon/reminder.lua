local mod = {}

local isAwake = {
  hs.caffeinate.watcher.screensaverDidStop,
  hs.caffeinate.watcher.sessionDidBecomeActive,
  hs.caffeinate.watcher.systemDidWake,
  hs.caffeinate.watcher.screensDidUnlock,
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
    local style = {
      fillColor = {alpha = 0.25, white = 0},
      radius = 10,
      strokeColor = {alpha = 0, white = 0},
      strokeWidth = 5,
      textColor = {alpha = 0.25, white = 1},
      textFont = "SauceCodePowerline-Regular",
      textSize = 100,
    }

    hs.alert('\n' .. padding .. message .. padding .. '\n', duration or 10, style)
    hs.sound.getByName("Hero"):play()
    hs.sound.getByName("Purr"):play()
  end
end

local function noticeActions(action)
  return function()
    local counter = 0
    local defaultInterval = 30

    local function increment(interval)
      counter = counter + interval
    end

    local function setupTimer(item)
      local interval = item.interval or defaultInterval
      hs.timer.doAfter(counter, notice(item.name .. ' ▶', interval - 1))
      increment(interval)
      hs.timer.doAfter(counter, notice('◀ ' .. item.name, interval - 1))
      increment(interval)
    end

    hs.fnutils.each(action, setupTimer)
  end
end

local function setReminder(item)
  if not item.timer then
    item.timer = hs.timer.doEvery(item.freq, item.fn or notice(item.name))
  end
  item.timer:stop():start()
end

local function stopReminder(item)
  item.timer:stop()
end

local function setReminders(reminders)
  hs.fnutils.each(reminders, setReminder)
end

local stretchesList = {{name = ''}}

local reminders = {{name = 'Break', freq = 1200, fn = noticeActions(stretchesList)}}

local function parseEvent(event)
  if hs.fnutils.contains(isAwake, event) then
    setReminders(reminders)
  end
end

mod.stretches = noticeActions(stretchesList)

function mod.reset()
  setReminders(reminders)
  hs.alert('Reminders have been reset.')
end

function mod.stop()
  hs.fnutils.each(reminders, stopReminder)
  hs.alert('Reminders have been stopped.')
end

function mod.init()
  setReminders(reminders)
  -- disabling reset for now
  -- hs.caffeinate.watcher.new(parseEvent):start()
end

return mod
