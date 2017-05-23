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
  { cmd = '~/org-calendar.sh' },
  { cmd = '~/org-pushbullet.sh' },
  { cmd = '/usr/local/bin/pipenv', args = { 'run', 'python', 'org-todoist.py' }}
}

local function checkStatus(exitCode, stdOut, stdErr)
  if exitCode ~= 0 then
    alert.show('the process failed to run, see logs')
    logger.d(stdOut)
    logger.d(stdErr)
  else
    logger.f('process done or terminated')
  end
end

local function stream(task, stdOut, stdErr)
  logger.d(stdOut)
  logger.d(stdErr)
  return true
end

local function expand(path)
  return path:gsub('~', HOME)
end

local function runTask(t)
  logger.df('scheduling: %s', t.cmd)
  return function()
    local env = {
      PATH = '/usr/local/bin:/usr/bin:/bin',
      LC_ALL = 'en_US.UTF-8',
      LANG = 'en_US.UTF-8',
      HOME = HOME
    }

    local args = t.args and t.args or {}
    local pwd = expand(t.pwd and t.pwd or '~/.bin')
    local process = task.new(expand(t.cmd), checkStatus, stream, args)

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
