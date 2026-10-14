-- Add a reminder to macOS Reminders, with a simple natural language due date.
--
--   "call bob in 30m"          -> due in 30 minutes
--   "call bob tomorrow 9am"    -> due tomorrow at 9:00
--   "call bob fri at 14:30"    -> due next Friday at 14:30
--   "call bob tonight"         -> due today at 20:00
--   "call bob 9pm"             -> due today at 21:00 (tomorrow if already past)
local logger = hs.logger.new('reminders', 'info')
local chrome = require 'chrome'

local mod = {}

-- Empty means the default Reminders list
mod.list = ''
local defaultHour = 9
local tonightHour = 20

local units = {
  m = 60, min = 60, mins = 60, minute = 60, minutes = 60,
  h = 3600, hr = 3600, hrs = 3600, hour = 3600, hours = 3600,
  d = 86400, day = 86400, days = 86400,
  w = 604800, wk = 604800, week = 604800, weeks = 604800,
}

local weekdays = {
  sun = 1, sunday = 1, mon = 2, monday = 2, tue = 3, tues = 3, tuesday = 3, wed = 4, wednesday = 4,
  thu = 5, thur = 5, thurs = 5, thursday = 5, fri = 6, friday = 6, sat = 7, saturday = 7,
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
    return rest, 0, tonightHour
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

-- Returns title and due date (epoch seconds, or nil)
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
    year = now.year, month = now.month, day = now.day + (days or 0),
    hour = hour or dayHour or defaultHour, min = minute or 0, sec = 0,
  })
  -- A bare time that already passed means tomorrow
  if not days and due <= nowEpoch then
    due = os.time({year = now.year, month = now.month, day = now.day + 1, hour = hour, min = minute, sec = 0})
  end
  return title, due
end

-- Extra details about where the reminder was created from, stored in its notes
local function __context(window)
  local app = window and window:application()
  if not app or app:name() ~= chrome.name then
    return nil
  end
  local ok, tab = hs.osascript.javascript(
    "const t = Application('" .. chrome.name .. "').windows[0].activeTab(); [t.title(), t.url()]")
  if not ok or type(tab) ~= 'table' then
    return nil
  end
  return {title = tab[1], url = tab[2]}
end

local function __create(title, due, notes)
  local params = hs.json.encode({name = title, due = due, list = mod.list, notes = notes})
  local script = [[
    const p = ]] .. params .. [[;
    const app = Application('Reminders');
    const props = {name: p.name};
    if (p.notes) props.body = p.notes;
    if (p.due) {
      props.dueDate = new Date(p.due * 1000);
      props.remindMeDate = new Date(p.due * 1000);
    }
    const list = p.list ? app.lists.byName(p.list) : app.defaultList();
    list.reminders.push(app.Reminder(props));
    true;
  ]]
  local ok, _, raw = hs.osascript.javascript(script)
  if not ok then
    logger.ef('Failed to create reminder: %s', hs.inspect(raw))
    if type(raw) == 'table' and raw.OSAScriptErrorNumberKey == -1743 then
      return false, 'Allow Hammerspoon → Reminders in Privacy & Security → Automation'
    end
  end
  return ok, 'Failed to create reminder, see console'
end

-- Only use real selections, never stale clipboard contents
local function __selectedText()
  local element = hs.uielement.focusedElement()
  local ok, text = pcall(function()
    return element and element:selectedText()
  end)
  if ok and text and text ~= '' then
    return text
  end
  local before = hs.pasteboard.changeCount()
  local initial = hs.pasteboard.readString()
  hs.eventtap.keyStroke({'cmd'}, 'c')
  hs.timer.usleep(150 * 1000)
  if hs.pasteboard.changeCount() == before then
    return ''
  end
  text = hs.pasteboard.readString() or ''
  if initial then
    hs.pasteboard.setContents(initial)
  end
  return text
end

function mod.add()
  local window = hs.window.focusedWindow()
  local context = __context(window)
  local raw = __selectedText():gsub('^%s+', ''):gsub('%s+$', '')
  local selected = raw:gsub('%s+', ' ')

  hs.focus()
  local help = 'e.g. "call bob tomorrow 9am", "in 30m", "fri at 14:30", "tonight"'
  if context then
    help = help .. '\n\n🔗 ' .. context.title .. '\n' .. context.url
  end
  local default = selected ~= '' and selected or (context and context.title or '')
  local button, text = hs.dialog.textPrompt('New Reminder', help, default, 'Add', 'Cancel')
  if window then
    window:focus()
  end
  if button ~= 'Add' or not text or text:match('^%s*$') then
    return
  end

  local title, due = mod.parse(text)
  local parts = {}
  if raw ~= '' then
    table.insert(parts, raw)
  end
  if context then
    table.insert(parts, context.title .. '\n' .. context.url)
  end
  local notes = #parts > 0 and table.concat(parts, '\n\n') or nil
  local ok, err = __create(title, due, notes)
  if ok then
    local when = due and (' — ' .. os.date('%a %b %d %H:%M', due)) or ''
    hs.alert.show('⏰ ' .. title .. when)
  else
    hs.alert.show(err, 5)
  end
end

return mod
