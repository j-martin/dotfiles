-- Syncs the in progress to-dos of Slack's To-dos tab with Reminders, while that tab is shown.
--
-- Slack has no API for to-dos, so they are read from the Slack app with accessibility, the same
-- way as github-review-reminders: each reminder note starts with the marker and the to-do key,
-- e.g. "slack-todos <C0A439Q0PNG-1793123686.123989>". Reminders without the marker are never
-- changed.
--
--   new to-do in Slack            -> reminder created
--   to-do gone from Slack         -> reminder completed
--   reminder completed            -> to-do marked complete in Slack, by hovering its row
--
-- Once done on both sides, the reminder is retired by renaming its marker to "slack-todos-done",
-- so the same message becoming a to-do again gets a new reminder.
--
-- Reminders are only completed when every in progress to-do was read, as Slack only renders the
-- visible part of long lists. Slack's To-dos filter applies, a filtered out to-do counts as gone.
local logger = require('utils/file_logger').new('slackTodos', 'info')
local nlpDate = require 'utils/nlp_date'
local reminders = require 'apps/reminders'
local slack = require 'apps/slack'

---@class SlackTodosModule
---@field marker string
---@field tag string
---@field interval number
---@field ttl number
---@field timer hs.timer|nil
---@field busy boolean True from reading Slack until every change is applied.
---@field task hs.task|nil
---@field ttlTimer hs.timer|nil
---@field windowFilter hs.window.filter|nil
---@field pending hs.timer|nil
---@field skipped string|nil Why the last sync was skipped, logged once until it changes.
---@field sync fun()
---@field init fun()
local mod = { busy = false }

mod.marker = 'slack-todos'

-- Reminders turns hashtags in the notes into tags.
mod.tag = '#slack'

-- Seconds between checks for the To-dos tab.
mod.interval = 60

-- Seconds before a sync is terminated.
mod.ttl = 60

---@class SlackTodoReminder
---@field key string
---@field title string
---@field notes string
---@field due number|nil

---@class SlackTodosPlan
---@field summary string
---@field toSlack table<string, string[]> To-do key -> ids of its completed reminders, to complete in Slack.

-- Creates and completes the reminders, then prints a SlackTodosPlan.
local syncScript = [[
function run(argv) {
  const p = JSON.parse(argv[0]);
  const app = Application('Reminders');
  const list = p.list ? app.lists.byName(p.list) : app.defaultList;
  const prefix = p.marker + ' <';
  const matches = list.reminders.whose({body: {_beginsWith: prefix}});
  const ids = matches.id();
  const bodies = matches.body();
  const completed = matches.completed();

  const byKey = {};
  ids.forEach((id, i) => {
    const line = bodies[i].split('\n')[0].trim();
    if (!line.endsWith('>')) return;
    const key = line.slice(prefix.length, -1);
    (byKey[key] = byKey[key] || []).push({id, body: bodies[i], completed: completed[i]});
  });
  const retire = r => {
    list.reminders.byId(r.id).body = r.body.replace(p.marker + ' <', p.marker + '-done <');
  };

  const wanted = new Set();
  const toSlack = {};
  const counts = {created: 0, completed: 0};
  for (const t of p.todos) {
    wanted.add(t.key);
    const existing = byKey[t.key] || [];
    if (existing.length === 0) {
      const props = {name: t.title, body: t.notes};
      if (t.due) props.dueDate = new Date(t.due * 1000);
      list.reminders.push(app.Reminder(props));
      counts.created++;
    } else if (existing.every(r => r.completed)) {
      toSlack[t.key] = existing.map(r => r.id);
    }
  }
  if (p.complete) {
    for (const key in byKey) {
      if (wanted.has(key)) continue;
      for (const r of byKey[key]) {
        if (!r.completed) {
          list.reminders.byId(r.id).completed = true;
          counts.completed++;
        }
        retire(r);
      }
    }
  }
  const summary = `${p.todos.length} to-dos, ${counts.created} created, ${counts.completed} completed`;
  return JSON.stringify({summary, toSlack});
}
]]

-- Renames the marker of the reminders, so they are no longer synced.
local retireScript = [[
function run(argv) {
  const p = JSON.parse(argv[0]);
  const app = Application('Reminders');
  const list = p.list ? app.lists.byName(p.list) : app.defaultList;
  for (const id of p.ids) {
    const r = list.reminders.byId(id);
    r.body = r.body().replace(p.marker + ' <', p.marker + '-done <');
  }
  return '';
}
]]

---@param todo SlackTodo
---@return SlackTodoReminder
local function toReminder(todo)
  local text = todo.text:gsub('%s+', ' ')
  local title = '💬 ' .. text
  local cut = utf8.offset(text, 101)
  if cut and cut <= #text then
    title = '💬 ' .. text:sub(1, cut - 1) .. '…'
  end
  local lines = { mod.marker .. ' <' .. todo.key .. '>', '' }
  if todo.url then
    table.insert(lines, todo.url)
  end
  if todo.author and todo.where then
    table.insert(lines, todo.author .. ' in ' .. todo.where)
  end
  local due = todo.due and nlpDate.parseSlack(todo.due) or nil
  if todo.due and not due then
    table.insert(lines, 'Due ' .. todo.due)
  end
  if cut and cut <= #text then
    table.insert(lines, '')
    table.insert(lines, text)
  end
  table.insert(lines, '')
  table.insert(lines, mod.tag)
  return {
    key = todo.key,
    title = title,
    notes = table.concat(lines, '\n'),
    due = due,
  }
end

-- Runs a JavaScript for Automation script with `params`, terminated after `mod.ttl` seconds.
---@param script string
---@param params table
---@param callback fun(output: string|nil) Receives nil when the script failed.
local function runScript(script, params, callback)
  local task = hs.task.new('/usr/bin/osascript', function(exitCode, stdOut, stdErr)
    if exitCode ~= 0 then
      logger.ef('Script failed (%d): %s', exitCode, (stdOut .. stdErr):gsub('%s+$', ''))
      callback(nil)
      return
    end
    callback((stdOut:gsub('%s+$', '')))
  end, { '-l', 'JavaScript', '-e', script, hs.json.encode(params) })
  mod.task = task
  task:start()
  mod.ttlTimer = hs.timer.doAfter(mod.ttl, function()
    if task:isRunning() then
      task:terminate()
    end
  end)
end

-- Marks the to-dos complete in Slack one at a time, then retires the reminders of those completed.
---@param window hs.window
---@param toSlack table<string, string[]>
local function completeInSlack(window, toSlack)
  ---@type string[]
  local keys = {}
  for key in pairs(toSlack) do
    table.insert(keys, key)
  end
  ---@type string[]
  local retired = {}

  ---@param index integer
  local function step(index)
    local key = keys[index]
    if not key then
      if #retired == 0 then
        mod.busy = false
        return
      end
      runScript(retireScript, { list = reminders.list, marker = mod.marker, ids = retired }, function()
        mod.busy = false
      end)
      return
    end
    slack.completeTodo(window, key, function(ok, err)
      if ok then
        logger.f('Completed %s in Slack', key)
        for _, id in ipairs(toSlack[key]) do
          table.insert(retired, id)
        end
      else
        logger.wf('Could not complete %s in Slack: %s', key, err)
      end
      step(index + 1)
    end)
  end
  step(1)
end

--- Syncs the to-dos when Slack shows its To-dos tab, unless a sync is running.
function mod.sync()
  if mod.busy then
    return
  end
  local window = slack.todosWindow()
  local read = window and slack.todos(window)
  if not window or not read then
    local reason = window and 'Could not find the In progress to-dos in Slack' or 'Slack is not showing its To-dos tab'
    if reason ~= mod.skipped then
      logger.f('%s, skipping', reason)
      mod.skipped = reason
    end
    return
  end
  mod.skipped = nil
  if not read.complete then
    logger.f('Read %d to-dos, fewer than Slack counts, so no reminder will be completed', #read.todos)
  end

  mod.busy = true
  local params = {
    list = reminders.list,
    marker = mod.marker,
    todos = hs.fnutils.map(read.todos, toReminder),
    complete = read.complete,
  }
  runScript(syncScript, params, function(output)
    local ok, plan = pcall(hs.json.decode, output or '')
    if not ok or type(plan) ~= 'table' then
      logger.ef('Unexpected sync output: %s', output)
      mod.busy = false
      return
    end
    ---@cast plan SlackTodosPlan
    local toSlack = 0
    for _ in pairs(plan.toSlack) do
      toSlack = toSlack + 1
    end
    -- Synced every minute, so only changes are logged.
    if toSlack > 0 or not plan.summary:match(' 0 created, 0 completed$') then
      logger.f('%s, %d to complete in Slack', plan.summary, toSlack)
    end
    completeInSlack(window, plan.toSlack)
  end)
end

--- Syncs every `mod.interval` seconds, and whenever a Slack window title changes, e.g. on opening the To-dos tab.
function mod.init()
  mod.timer = hs.timer.doEvery(mod.interval, mod.sync)
  mod.windowFilter = hs.window.filter.new(slack.name):subscribe(hs.window.filter.windowTitleChanged, function()
    if mod.pending then
      mod.pending:stop()
    end
    mod.pending = hs.timer.doAfter(1, mod.sync)
  end)
  mod.sync()
end

return mod
