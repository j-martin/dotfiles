local task = require "hs.task"
local fnutils = require "hs.fnutils"
local alert = require "hs.alert"
local logger = hs.logger.new('execute', 'debug')

local mod = {}

local running_processes = {}
local HOME = os.getenv('HOME')
local env = {
  PATH = '/usr/local/bin:/usr/bin:/bin',
  LC_ALL = 'en_US.UTF-8',
  LANG = 'en_US.UTF-8',
  HOME = HOME
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

function getn (t)
  if type(t.n) == "number" then return t.n end
  local max = 0
  for i, _ in t do
    if type(i) == "number" and i>max then max=i end
  end
  return max
end

local function cleanupProcess(task)
  logger.df("Checking if still running: %s", task:pid())
  return task:isRunning()
end

local function expand(path)
  return path:gsub('~', HOME)
end

function mod.start(cmd, args, pwd)
  running_processes = fnutils.filter(running_processes, cleanupProcess)

  cmd = expand(cmd)
  args = fnutils.map(args or {}, expand)
  pwd = expand(pwd or '~/.bin')

  process = task.new(cmd, nil, function() end, args)
  table.insert(running_processes, process)

  logger.f('starting %s %s in %s', cmd, args, pwd)
  process:setWorkingDirectory(pwd)
  process:setEnvironment(env)

  if not process:start() then
    logger.df('failed to start %s', cmd)
  end

  return process
end

return mod
