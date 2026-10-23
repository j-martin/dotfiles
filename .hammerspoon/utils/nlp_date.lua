-- Parse a simple natural language date at the end of a text.
--
--   "call bob in 30m"          -> in 30 minutes
--   "call bob tomorrow 9am"    -> tomorrow at 9:00
--   "call bob fri at 14:30"    -> next Friday at 14:30
--   "call bob tonight"         -> today at 20:00
--   "call bob 9pm"             -> today at 21:00 (tomorrow if already past)
local mod = {}

mod.defaultHour = 9
mod.tonightHour = 20

local units = {
  m = 60,
  min = 60,
  mins = 60,
  minute = 60,
  minutes = 60,
  h = 3600,
  hr = 3600,
  hrs = 3600,
  hour = 3600,
  hours = 3600,
  d = 86400,
  day = 86400,
  days = 86400,
  w = 604800,
  wk = 604800,
  week = 604800,
  weeks = 604800,
}

local weekdays = {
  sun = 1,
  sunday = 1,
  mon = 2,
  monday = 2,
  tue = 3,
  tues = 3,
  tuesday = 3,
  wed = 4,
  wednesday = 4,
  thu = 5,
  thur = 5,
  thurs = 5,
  thursday = 5,
  fri = 6,
  friday = 6,
  sat = 7,
  saturday = 7,
}

-- Strip a trailing day word; returns rest, days offset from today (or nil), default hour
local function __takeDay(text, now)
  local rest, word = text:match('^(.-)%s+on%s+(%a+)$')
  if not word then
    rest, word = text:match('^(.-)%s+(%a+)$')
  end
  if not word then
    return text
  end
  word = word:lower()
  if word == 'today' then
    return rest, 0
  elseif word == 'tonight' then
    return rest, 0, mod.tonightHour
  elseif word == 'tomorrow' or word == 'tmr' or word == 'tmrw' then
    return rest, 1
  elseif weekdays[word] then
    local offset = (weekdays[word] - now.wday) % 7
    return rest, offset == 0 and 7 or offset
  end
  return text
end

-- Strip a trailing time; returns rest, hour, minute (or nil)
local function __takeTime(text)
  local patterns = {
    '^(.-)%s+at%s+(%d%d?):?(%d?%d?)%s*([aApP]?[mM]?)$',
    '^(.-)%s+(%d%d?):(%d%d)%s*([aApP]?[mM]?)$',
    '^(.-)%s+(%d%d?)(:?)%s*([aApP][mM])$',
  }
  for _, pattern in ipairs(patterns) do
    local rest, hour, minute, ampm = text:match(pattern)
    if rest then
      hour, minute, ampm = tonumber(hour), tonumber(minute) or 0, ampm:lower()
      if ampm == 'pm' and hour < 12 then
        hour = hour + 12
      elseif ampm == 'am' and hour == 12 then
        hour = 0
      end
      if hour < 24 and minute < 60 then
        return rest, hour, minute
      end
    end
  end
  return text
end

--- Returns the text without its trailing date, and that date (epoch seconds, or nil)
function mod.parse(text, nowEpoch)
  text = text:gsub('^%s+', ''):gsub('%s+$', '')
  nowEpoch = nowEpoch or os.time()
  local now = os.date('*t', nowEpoch)

  local rest, amount, unit = text:match('^(.-)%s+in%s+(%d+)%s*(%a+)$')
  if rest and units[unit:lower()] then
    return rest, nowEpoch + tonumber(amount) * units[unit:lower()]
  end

  -- Day and time in either order: "tomorrow 9am" or "9am tomorrow"
  local title, days, dayHour, hour, minute = text, nil, nil, nil, nil
  for _ = 1, 2 do
    if not hour then
      title, hour, minute = __takeTime(title)
    end
    if not days then
      title, days, dayHour = __takeDay(title, now)
    end
  end
  if not days and not hour then
    return text, nil
  end

  local due = os.time({
    year = now.year,
    month = now.month,
    day = now.day + (days or 0),
    hour = hour or dayHour or mod.defaultHour,
    min = minute or 0,
    sec = 0,
  })
  -- A bare time that already passed means tomorrow
  if not days and due <= nowEpoch then
    due = os.time({ year = now.year, month = now.month, day = now.day + 1, hour = hour, min = minute, sec = 0 })
  end
  return title, due
end

return mod
