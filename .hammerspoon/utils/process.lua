local logger = hs.logger.new('execute', 'debug')

local mod = {}

local running_processes = {}
local HOME = os.getenv('HOME')
local env = {PATH = '/usr/local/bin:/usr/bin:/bin', LC_ALL = 'en_US.UTF-8', LANG = 'en_US.UTF-8', HOME = HOME}

local function returnCallback(exitCode, stdOut, stdErr)
  if exitCode ~= 0 then
    hs.alert.show('the process failed to run, see logs')
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

function getn(t)
  if type(t.n) == "number" then
    return t.n
  end
  local max = 0
  for i, _ in t do
    if type(i) == "number" and i > max then
      max = i
    end
  end
  return max
end

local function cleanupProcess(process)
  task = process.task
  logger.df("Checking if still running: %s", task:pid())
  if not task:isRunning() then
    logger.df("The process is not running anymore: %s", task:pid())
    return false
  end
  if process.ttl < mod.getEpoch then
    logger.df("Terminating due to TTL: %s", task:pid())
    task:terminate()
  end
  logger.df("The process is still running: %s", task:pid())
  return true
end

local function expand(path)
  return path:gsub('~', HOME)
end


function mod.getEpoch()
  return os.time(os.date("!*t"))
end

function mod.start(cmd, args, pwd, ttl)
  running_processes = hs.fnutils.filter(running_processes, cleanupProcess)

  cmd = expand(cmd)
  args = hs.fnutils.map(args or {}, expand)
  pwd = expand(pwd or '~/.bin')

  task = hs.task.new(cmd, returnCallback, streamCallback, args)
  table.insert(running_processes, {task = task, ttl = mod.getEpoch() + (ttl or 30) })

  logger.f('starting %s %s in %s', cmd, hs.inspect(args), pwd)
  task:setWorkingDirectory(pwd)
  task:setEnvironment(env)

  if not task:start() then
    logger.df('failed to start %s', cmd)
  end

  return task
end

return mod
