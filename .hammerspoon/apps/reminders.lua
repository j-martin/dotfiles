-- Add a reminder to macOS Reminders, with a simple natural language due date.
--
--   "call bob in 30m"          -> due in 30 minutes
--   "call bob tomorrow 9am"    -> due tomorrow at 9:00
--   "call bob fri at 14:30"    -> due next Friday at 14:30
--   "call bob tonight"         -> due today at 20:00
--   "call bob 9pm"             -> due today at 21:00 (tomorrow if already past)
local logger = hs.logger.new('reminders', 'info')
local selection = require 'selection'
local nlpDate = require 'utils/nlp_date'

---@class ReminderContext
---@field title string
---@field url string|nil
---@field details string[]|nil
---@field selection string|nil

---@class RemindersApp
---@field name string
---@field list string
---@field create fun(title: string, due: number|nil, notes: string|nil): boolean, string
---@field add fun()
local mod = {}

mod.name = 'Reminders'

-- Empty means the default Reminders list.
-- Lists inside a list group are not scriptable, only top level lists can be named here.
mod.list = ''

--- Creates a reminder in `mod.list`. Returns ok, and an error message when not ok.
---@param title string
---@param due number|nil
---@param notes string|nil
---@return boolean, string
function mod.create(title, due, notes)
  local params = hs.json.encode({ name = title, due = due, list = mod.list, notes = notes })
  local script = [[
    const p = ]] .. params .. [[;
    const app = Application(']] .. mod.name .. [[');
    const props = {name: p.name};
    if (p.notes) props.body = p.notes;
    if (p.due) {
      props.dueDate = new Date(p.due * 1000);
      props.remindMeDate = new Date(p.due * 1000);
    }
    const list = p.list ? app.lists.byName(p.list) : app.defaultList;
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

-- Title, link and details, one per line
---@param context ReminderContext
---@return string
local function __describe(context)
  local lines = { context.title }
  if context.url then
    table.insert(lines, context.url)
  end
  for _, detail in ipairs(context.details or {}) do
    table.insert(lines, detail)
  end
  return table.concat(lines, '\n')
end

-- Single row previewing the parsed title and due date
---@param query string
---@param context ReminderContext|nil
---@return table
local function __preview(query, context)
  local title, due = nlpDate.parse(query)
  local subText = due and ('⏰ ' .. os.date('%a %b %d %H:%M', due)) or 'No due date'
  if context then
    subText = subText .. '   🔗 ' .. context.title
  end
  return { { text = title ~= '' and title or 'New reminder', subText = subText, query = query } }
end

-- Creates the reminder from the typed text, keeping the selection and context in its notes
---@param text string
---@param raw string
---@param oneLine string
---@param context ReminderContext|nil
local function __submit(text, raw, oneLine, context)
  local title, due = nlpDate.parse(text)
  local parts = {}
  if raw ~= '' and title:gsub('%s+', ' ') ~= oneLine then
    table.insert(parts, raw)
  end
  if context then
    table.insert(parts, __describe(context))
  end
  local notes = #parts > 0 and table.concat(parts, '\n\n') or nil
  mod.createTimer = hs.timer.doAfter(0.1, function()
    local ok, err = mod.create(title, due, notes)
    if ok then
      local when = due and (' — ' .. os.date('%a %b %d %H:%M', due)) or ''
      hs.alert.show('⏰ ' .. title .. when)
    else
      hs.alert.show(err, 5)
    end
  end)
end

--- Prompts for a reminder, prefilled with the selected text, and with what the focused window shows in its notes.
function mod.add()
  local apps = require 'apps'
  local window = hs.window.focusedWindow()
  local context = apps.context(window)
  if not context and window then
    context = { title = window:application():name() .. ' — ' .. window:title() }
  end
  local selected = context and context.selection or selection.getSelectedText()
  local raw = selected:gsub('^%s+', ''):gsub('%s+$', '')
  local oneLine = raw:gsub('%s+', ' ')

  local default = oneLine ~= '' and oneLine or (context and context.title or '')

  if mod.chooser then
    mod.chooser:delete()
  end
  mod.chooser = hs.chooser.new(function(choice)
    if window then
      window:focus()
    end
    if not choice or choice.query:match('^%s*$') then
      return
    end
    __submit(choice.query, raw, oneLine, context)
  end)
  mod.chooser:placeholderText('Remind me to… e.g. "call bob tomorrow 9am", "in 30m", "fri at 14:30"')
  mod.chooser:rows(1)
  mod.chooser:bgDark(true)
  mod.chooser:queryChangedCallback(function(query)
    mod.chooser:choices(__preview(query, context))
  end)
  mod.chooser:query(default)
  mod.chooser:choices(__preview(default, context))
  mod.chooser:show()
end

return mod
