local task = require "hs.task"
local fnutils = require "hs.fnutils"
local timer = require "hs.timer"
local alert = require "hs.alert"
local logger = hs.logger.new('schedule', 'debug')

local mod = {}

local HOME = os.getenv('HOME')

-- why, this instead of cron? keyring doesn't work very well with cron, and
-- using pipenv is also finicky.
-- where pwd = ~/.bin
local tasks = {
  { cmd = '/bin/bash', args = { 'org-calendar.sh' }},
  { cmd = '~/.bin/org-pushbullet/target/release/org-pushbullet', args = { '~/.org/references/' }},
  { cmd = '/usr/local/bin/pipenv', args = { 'run', 'python', 'org-todoist.py' }}
}

local function returnCallback(exitCode, stdOut, stdErr)
  if exitCode ~= 0 then
    alert.show('the process failed to run, see logs')
    logger.d(stdOut)
    logger.d(stdErr)
    return false
  end
  logger.f('process done')
  return true
end

local function streamCallback(_, stdOut, stdErr)
  logger.d(stdOut)
  logger.d(stdErr)
  return true
end

local function expand(path)
  return path:gsub('~', HOME)
end

local function runTask(t)
  local cmd = expand(t.cmd)
  local args = t.args and t.args or {}
  args = fnutils.map(args, expand)
  logger.df('scheduling: %s %s', cmd, args[1])
  return function()
    local env = {
      PATH = '/usr/local/bin:/usr/bin:/bin',
      LC_ALL = 'en_US.UTF-8',
      LANG = 'en_US.UTF-8',
      HOME = HOME
    }

    local pwd = expand(t.pwd and t.pwd or '~/.bin')
    local process = task.new(cmd, returnCallback, streamCallback, args)

    logger.f('starting job %s %s in %s', t.cmd, args, pwd)
    process:setWorkingDirectory(pwd)
    process:setEnvironment(env)
    if not process:start() then
      logger.df('failed to start %s', t.cmd)
    end
  end
end

local function scheduleTask(t)
  local interval = t.interval
  if not interval then
    interval = 1800
  end
  timer.doEvery(interval, runTask(t))
end

function mod.init()
  fnutils.each(tasks, scheduleTask)
end

return mod
