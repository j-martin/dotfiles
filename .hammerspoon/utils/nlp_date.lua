-- Parse a simple natural language date at the end of a text.
--
--   "call bob in 30m"          -> in 30 minutes
--   "call bob tomorrow 9am"    -> tomorrow at 9:00
--   "call bob fri at 14:30"    -> next Friday at 14:30
--   "call bob tonight"         -> today at 20:00
--   "call bob 9pm"             -> today at 21:00 (tomorrow if already past)
--   "call bob at 7"            -> 19:00 (bare 1-11 means pm; "at 07" or "7am" for morning)
---@class NlpDateModule
---@field defaultHour number
---@field tonightHour number
---@field parse fun(text: string, nowEpoch: number|nil): string, number|nil
---@field parseSlack fun(text: string, nowEpoch: number|nil): number|nil
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
---@param text string
---@param now table
---@return string, number|nil, number|nil
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
---@param text string
---@return string, number|nil, number|nil
local function __takeTime(text)
  local patterns = {
    '^(.-)%s+at%s+(%d%d?):?(%d?%d?)%s*([aApP]?[mM]?)$',
    '^(.-)%s+(%d%d?):(%d%d)%s*([aApP]?[mM]?)$',
    '^(.-)%s+(%d%d?)(:?)%s*([aApP][mM])$',
  }
  for _, pattern in ipairs(patterns) do
    local rest, hour, minute, ampm = text:match(pattern)
    if rest then
      local hasLeadingZero = hour:sub(1, 1) == '0'
      hour, minute, ampm = tonumber(hour), tonumber(minute) or 0, ampm:lower()
      if ampm == '' and not hasLeadingZero and hour >= 1 and hour < 12 then
        hour = hour + 12
      elseif ampm == 'pm' and hour < 12 then
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
---@param text string
---@param nowEpoch number|nil
---@return string, number|nil
function mod.parse(text, nowEpoch)
  text = text:gsub('^%s+', ''):gsub('%s+$', '')
  nowEpoch = nowEpoch or os.time()
  local now = os.date('*t', nowEpoch)

  local rest, amount, unit = text:match('^(.-)%s+in%s+(%d+)%s*(%a+)$')
  if rest and units[unit:lower()] then
    return rest, nowEpoch + tonumber(amount) * units[unit:lower()]
  end

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
  if not days and due <= nowEpoch then
    due = os.time({ year = now.year, month = now.month, day = now.day + 1, hour = hour, min = minute, sec = 0 })
  end
  return title, due
end

---@type table<string, integer>
local months =
  { jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12 }

--- Returns the date as Slack shows it, e.g. "Yesterday at 10:54", "Oct 30th at 9:00 AM" (epoch seconds, or nil)
---@param text string
---@param nowEpoch number|nil
---@return number|nil
function mod.parseSlack(text, nowEpoch)
  local day, hour, minute, ampm = text:lower():match('^(.-)%s+at%s+(%d%d?):(%d%d)%s*([ap]?m?)$')
  if not day then
    return nil
  end
  local now = os.date('*t', nowEpoch or os.time())
  ---@type osdateparam
  local date =
    { year = now.year, month = now.month, day = now.day, hour = tonumber(hour), min = tonumber(minute), sec = 0 }
  if ampm == 'pm' and date.hour < 12 then
    date.hour = date.hour + 12
  elseif ampm == 'am' and date.hour == 12 then
    date.hour = 0
  end
  local offsets = { today = 0, tomorrow = 1, yesterday = -1 }
  local monthName, dayOfMonth = day:match('^(%a%a%a)%a*%.?%s+(%d%d?)%a*$')
  if offsets[day] then
    date.day = date.day + offsets[day]
  elseif weekdays[day] then
    date.day = date.day + (weekdays[day] - now.wday) % 7
  elseif monthName and months[monthName] then
    date.month, date.day = months[monthName], tonumber(dayOfMonth)
  else
    return nil
  end
  return os.time(date)
end

return mod
