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
local jxa = require 'utils/jxa'

---@class ReminderContext
---@field title string
---@field url string|nil
---@field details string[]|nil
---@field selection string|nil

---@class RemindersApp
---@field name string
---@field list string
---@field fallbackList string
---@field resolveListScript string
---@field create fun(title: string, due: number|nil, notes: string|nil, list: string|nil): boolean, string
---@field fetchLists fun(callback: fun(names: string[]|nil, err: string|nil))
---@field add fun()
local mod = {}

mod.name = 'Reminders'

-- Empty means the default Reminders list, or `mod.fallbackList` when there is no default list.
-- Lists inside a list group are not scriptable, only top level lists can be named here.
mod.list = ''

-- Reminders list used when `mod.list` is empty and there is no default list.
mod.fallbackList = 'Work'

-- JXA `resolveList(app, name)`: the list named `name`, or the default list when `name` is empty, or
-- `mod.fallbackList` when there is no default list. Prepend it to the scripts using it.
mod.resolveListScript = [[
function resolveList(app, name) {
  if (name) {
    const list = app.lists.byName(name);
    if (!list.exists()) {
      throw new Error('Reminders list not found: ' + name);
    }
    return list;
  }
  if (app.defaultList.exists()) {
    return app.defaultList;
  }
  const fallback = app.lists.byName(]] .. jxa.jsString(mod.fallbackList) .. [[);
  if (!fallback.exists()) {
    throw new Error(]] .. jxa.jsString('No default Reminders list and no list named ' .. mod.fallbackList) .. [[);
  }
  return fallback;
}
]]

--- Creates a reminder in `list`, `mod.list` by default. Returns ok, and an error message when not ok.
---@param title string
---@param due number|nil
---@param notes string|nil
---@param list string|nil
---@return boolean, string
function mod.create(title, due, notes, list)
  local params = hs.json.encode({ name = title, due = due, list = list or mod.list, notes = notes })
  local script = mod.resolveListScript
    .. [[
    const p = ]]
    .. params
    .. [[;
    const app = Application(']]
    .. mod.name
    .. [[');
    const props = {name: p.name};
    if (p.notes) props.body = p.notes;
    if (p.due) {
      props.dueDate = new Date(p.due * 1000);
      props.remindMeDate = new Date(p.due * 1000);
    }
    const list = resolveList(app, p.list);
    list.reminders.push(app.Reminder(props));
    true;
  ]]
  local ok, _, err = jxa.run(script)
  if not ok then
    logger.ef('Failed to create reminder: %s', err)
    if err and err:find('(-1743)', 1, true) then
      return false, 'Allow Hammerspoon → Reminders in Privacy & Security → Automation'
    end
  end
  return ok, 'Failed to create reminder, see console'
end

--- Fetches the names of the top level Reminders lists, the list `mod.create` uses by default first.
---@param callback fun(names: string[]|nil, err: string|nil)
function mod.fetchLists(callback)
  local script = mod.resolveListScript
    .. [[
    const app = Application(']]
    .. mod.name
    .. [[');
    const preferred = resolveList(app, ]]
    .. jxa.jsString(mod.list)
    .. [[).name();
    [preferred].concat(app.lists.name().filter((name) => name !== preferred));
  ]]
  mod.listsTask = jxa.start(script, function(ok, names, err)
    if not ok then
      logger.ef('Failed to fetch the Reminders lists: %s', err)
      callback(nil, 'Failed to fetch the Reminders lists, see console')
      return
    end
    callback(names, nil)
  end)
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

-- Rows previewing the parsed title and due date: with notes, and a second one without when there would be notes
---@param query string
---@param context ReminderContext|nil
---@param hasNotes boolean
---@return table
local function __preview(query, context, hasNotes)
  local title, due = nlpDate.parse(query)
  ---@type string
  local text = title ~= '' and title or 'New reminder'
  ---@type string
  local dueText = due and ('⏰ ' .. os.date('%a %b %d %H:%M', due)) or 'No due date'
  ---@type string
  local subText = dueText
  if context then
    subText = subText .. '   🔗 ' .. context.title
  end
  local rows = { { text = text, subText = subText, query = query } }
  if hasNotes then
    table.insert(rows, { text = text, subText = dueText .. '   🚫 No note', query = query, noNote = true })
  end
  return rows
end

-- Creates the reminder from the typed text, keeping the selection and context in its notes
---@param text string
---@param raw string
---@param oneLine string
---@param context ReminderContext|nil
---@param noNote boolean|nil When true, the reminder gets no notes at all
---@param list string
local function __submit(text, raw, oneLine, context, noNote, list)
  local title, due = nlpDate.parse(text)
  ---@type string[]
  local parts = {}
  if noNote then
    raw, context = '', nil
  end
  if raw ~= '' and title:gsub('%s+', ' ') ~= oneLine then
    table.insert(parts, raw)
  end
  if context then
    table.insert(parts, __describe(context))
  end
  local notes = #parts > 0 and table.concat(parts, '\n\n') or nil
  mod.createTimer = hs.timer.doAfter(0.1, function()
    local ok, err = mod.create(title, due, notes, list)
    if ok then
      local when = due and (' — ' .. os.date('%a %b %d %H:%M', due)) or ''
      hs.alert.show('⏰ ' .. title .. when .. ' — ' .. list)
    else
      hs.alert.show(err, 5)
    end
  end)
end

-- Prompts for the reminder, then calls `onText` with the typed text, deferred so the chooser can be replaced
---@param window hs.window|nil
---@param context ReminderContext|nil
---@param raw string
---@param oneLine string
---@param onText fun(text: string, noNote: boolean|nil)
local function __promptReminder(window, context, raw, oneLine, onText)
  local default = oneLine ~= '' and oneLine or (context and context.title or '')
  ---@type boolean
  local hasNotes = context ~= nil or raw ~= ''

  if mod.chooser then
    mod.chooser:delete()
  end
  mod.chooser = hs.chooser.new(function(choice)
    if not choice or choice.query:match('^%s*$') then
      if window then
        window:focus()
      end
      return
    end
    mod.promptTimer = hs.timer.doAfter(0, function()
      onText(choice.query, choice.noNote)
    end)
  end)
  mod.chooser:placeholderText('Remind me to… e.g. "call bob tomorrow 9am", "in 30m", "fri at 14:30"')
  mod.chooser:rows(hasNotes and 2 or 1)
  mod.chooser:bgDark(true)
  mod.chooser:queryChangedCallback(function(query)
    mod.chooser:choices(__preview(query, context, hasNotes))
  end)
  mod.chooser:query(default)
  mod.chooser:choices(__preview(default, context, hasNotes))
  mod.chooser:show()
end

-- Prompts for the list to add the reminder to, the default list first, then calls `onList` with it
---@param names string[]
---@param window hs.window|nil
---@param onList fun(list: string)
local function __promptList(names, window, onList)
  if #names == 1 then
    if window then
      window:focus()
    end
    onList(names[1])
    return
  end
  if mod.chooser then
    mod.chooser:delete()
  end
  mod.chooser = hs.chooser.new(function(choice)
    if window then
      window:focus()
    end
    if choice then
      onList(choice.text)
    end
  end)
  mod.chooser:placeholderText('Reminders list…')
  mod.chooser:bgDark(true)
  mod.chooser:choices(hs.fnutils.map(names, function(name)
    return { text = name }
  end))
  mod.chooser:show()
end

--- Prompts for a reminder, prefilled with the selected text, and with what the focused window shows in its notes,
--- then for the list to add it to.
function mod.add()
  local apps = require 'apps'
  local window = hs.window.focusedWindow()
  local context = apps.windowContext(window)
  local selected = context and context.selection or selection.getSelectedText()
  local raw = selected:gsub('^%s+', ''):gsub('%s+$', '')
  local oneLine = raw:gsub('%s+', ' ')

  ---@type string[]|nil, string|nil, fun()|nil
  local names, fetchErr, pending
  local fetched = false
  mod.fetchLists(function(fetchedNames, err)
    names, fetchErr, fetched = fetchedNames, err, true
    if pending then
      pending()
    end
  end)

  __promptReminder(window, context, raw, oneLine, function(text, noNote)
    pending = function()
      if not names or #names == 0 then
        if window then
          window:focus()
        end
        hs.alert.show(fetchErr or 'No Reminders list', 5)
        return
      end
      __promptList(names, window, function(list)
        __submit(text, raw, oneLine, context, noNote, list)
      end)
    end
    if fetched then
      pending()
    end
  end)
end

return mod
