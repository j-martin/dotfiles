local nlpDate = require 'utils/nlp_date'

-- Tuesday 2026-10-27 06:00 local time
---@type integer
local now = os.time({ year = 2026, month = 10, day = 27, hour = 6, min = 0, sec = 0 })

--- Asserts that `text` parses to `expectedTitle` due at the given local date and time
---@param text string
---@param expectedTitle string
---@param expected string formatted as '%Y-%m-%d %H:%M'
local function assertParses(text, expectedTitle, expected)
  local title, due = nlpDate.parse(text, now)
  assert(title == expectedTitle, string.format('title: expected %q, got %q', expectedTitle, title))
  assert(due, string.format('%q: expected a due date', text))
  ---@type string
  local actual = os.date('%Y-%m-%d %H:%M', due) --[[@as string]]
  assert(actual == expected, string.format('%q: expected %s, got %s', text, expected, actual))
end

--- Asserts that the Slack date `text` parses to the given local date and time
---@param text string
---@param expected string formatted as '%Y-%m-%d %H:%M'
local function assertParsesSlack(text, expected)
  local due = nlpDate.parseSlack(text, now)
  assert(due, string.format('%q: expected a due date', text))
  ---@type string
  local actual = os.date('%Y-%m-%d %H:%M', due) --[[@as string]]
  assert(actual == expected, string.format('%q: expected %s, got %s', text, expected, actual))
end

---@type table<string, fun()>
return {
  ['slack yesterday'] = function()
    assertParsesSlack('Yesterday at 10:54', '2026-10-26 10:54')
  end,
  ['slack tomorrow with pm'] = function()
    assertParsesSlack('Tomorrow at 1:30 PM', '2026-10-28 13:30')
  end,
  ['slack 12 am is midnight'] = function()
    assertParsesSlack('Today at 12:15 AM', '2026-10-27 00:15')
  end,
  ['slack weekday is upcoming'] = function()
    assertParsesSlack('Friday at 09:00', '2026-10-30 09:00')
  end,
  ['slack month and ordinal day'] = function()
    assertParsesSlack('Nov 3rd at 14:00', '2026-11-03 14:00')
  end,
  ['slack unknown date is nil'] = function()
    assert(nlpDate.parseSlack('Someday at 10:00', now) == nil)
    assert(nlpDate.parseSlack('Tomorrow', now) == nil)
  end,
  ['bare hour 7 means 19:00'] = function()
    assertParses('call bob at 7', 'call bob', '2026-10-27 19:00')
  end,
  ['bare hour 1 means 13:00'] = function()
    assertParses('call bob at 1', 'call bob', '2026-10-27 13:00')
  end,
  ['leading zero keeps the morning hour'] = function()
    assertParses('call bob at 07', 'call bob', '2026-10-27 07:00')
  end,
  ['leading zero with minutes keeps the morning hour'] = function()
    assertParses('call bob at 0730', 'call bob', '2026-10-27 07:30')
  end,
  ['bare hour with minutes means pm'] = function()
    assertParses('call bob tomorrow at 9:30', 'call bob', '2026-10-28 21:30')
  end,
  ['12 stays noon'] = function()
    assertParses('call bob at 12', 'call bob', '2026-10-27 12:00')
  end,
  ['24h time is unchanged'] = function()
    assertParses('call bob 14:30', 'call bob', '2026-10-27 14:30')
  end,
  ['explicit am is respected'] = function()
    assertParses('call bob 7am', 'call bob', '2026-10-27 07:00')
  end,
  ['explicit pm is respected'] = function()
    assertParses('call bob 7pm', 'call bob', '2026-10-27 19:00')
  end,
  ['12am is midnight, moved to tomorrow when past'] = function()
    assertParses('call bob 12am', 'call bob', '2026-10-28 00:00')
  end,
  ['relative duration'] = function()
    assertParses('call bob in 30m', 'call bob', '2026-10-27 06:30')
  end,
  ['tonight defaults to 20:00'] = function()
    assertParses('call bob tonight', 'call bob', '2026-10-27 20:00')
  end,
  ['tomorrow defaults to 9:00'] = function()
    assertParses('call bob tomorrow', 'call bob', '2026-10-28 09:00')
  end,
  ['weekday with time'] = function()
    assertParses('call bob fri at 14:30', 'call bob', '2026-10-30 14:30')
  end,
  ['same weekday means next week'] = function()
    assertParses('call bob tue', 'call bob', '2026-11-03 09:00')
  end,
  ['text without a date is returned untouched'] = function()
    local title, due = nlpDate.parse('call bob', now)
    assert(title == 'call bob' and due == nil, 'expected no date')
  end,
}
