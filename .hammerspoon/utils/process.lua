local logger = hs.logger.new('execute', 'debug')

---@class ProcessOptions
---@field env table<string, string>|nil Added to, or overriding, the default environment.
---@field callback fun(exitCode: number, stdOut: string, stdErr: string)|nil Replaces the default completion callback, and receives the whole output instead of it being streamed to the logs.
---@field quiet boolean|nil Does not log the arguments, e.g. when they hold a whole script.

---@class ProcessModule
---@field paths string[] Directories searched for executables, mise shims first.
---@field PATH string `paths` joined, used by every process started by this module.
---@field getEpoch fun(): number
---@field which fun(exec: string): string
---@field execute fun(command: string): string, boolean|nil, string|nil, number|nil
---@field start fun(cmd: string, args: string[]|nil, pwd: string|nil, ttl: number|nil, options: ProcessOptions|nil): hs.task
local mod = {}

local running_processes = {}
local HOME = os.getenv('HOME')

-- Hammerspoon inherits the bare launchd PATH, so tools installed with mise or Homebrew must be added.
mod.paths = {
  HOME .. '/.local/share/mise/shims',
  HOME .. '/bin',
  '/opt/homebrew/bin',
  '/usr/local/bin',
  '/usr/bin',
  '/bin',
  '/usr/sbin',
  '/sbin',
}
mod.PATH = table.concat(mod.paths, ':')

---@type table<string, string>
local env = { PATH = mod.PATH, LC_ALL = 'en_US.UTF-8', LANG = 'en_US.UTF-8', HOME = HOME }

---@param exitCode number
---@param stdOut string
---@param stdErr string
---@return boolean
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

---@param _ any
---@param stdOut string
---@param stdErr string
---@return boolean
local function streamCallback(_, stdOut, stdErr)
  logger.d(stdOut)
  logger.d(stdErr)
  return true
end

---@param t table
---@return number
function getn(t)
  if type(t.n) == 'number' then
    return t.n
  end
  local max = 0
  for i, _ in t do
    if type(i) == 'number' and i > max then
      max = i
    end
  end
  return max
end

---@param process table
---@return boolean
local function cleanupProcess(process)
  local task = process.task
  logger.df('Checking if still running: %s', task:pid())
  if not task:isRunning() then
    logger.df('The process is not running anymore: %s', task:pid())
    return false
  end
  if process.ttl < mod.getEpoch() then
    logger.df('Terminating due to TTL: %s', task:pid())
    task:terminate()
  end
  logger.df('The process is still running: %s', task:pid())
  return true
end

-- Only a leading `~` is expanded, so URLs and scripts passed as arguments are kept intact.
---@param path string
---@return string
local function expand(path)
  return (path:gsub('^~', HOME))
end

--- Returns the current Unix epoch in seconds.
---@return number
function mod.getEpoch()
  return os.time(os.date('!*t') --[[@as osdateparam]])
end

--- Returns the absolute path of the executable found first in `mod.paths`, or the name when not found.
---@param exec string
---@return string
function mod.which(exec)
  for _, dir in ipairs(mod.paths) do
    ---@type string
    local path = dir .. '/' .. exec
    if hs.fs.attributes(path) then
      return path
    end
  end
  logger.wf('Could not find %s in %s', exec, mod.PATH)
  return exec
end

--- Runs a shell command synchronously with `mod.PATH`, like `hs.execute`.
---@param command string
---@return string output
---@return boolean|nil status
---@return string|nil exitType
---@return number|nil rc
function mod.execute(command)
  local f = io.popen("export PATH='" .. mod.PATH .. "'; " .. command, 'r')
  if not f then
    logger.ef('Could not run: %s', command)
    return '', nil, nil, nil
  end
  ---@type string
  local output = f:read('*a')
  local status, exitType, rc = f:close()
  return output, status, exitType, rc
end

---@param cmd string
---@param args string[]|nil
---@param pwd string|nil
---@param ttl number|nil
---@param options ProcessOptions|nil
---@return hs.task
function mod.start(cmd, args, pwd, ttl, options)
  running_processes = hs.fnutils.filter(running_processes, cleanupProcess)

  cmd = expand(cmd)
  if not cmd:find('/') then
    cmd = mod.which(cmd)
  end
  args = hs.fnutils.map(args or {}, expand)
  pwd = expand(pwd or '~/.bin')

  options = options or {}
  local task
  if options.callback then
    task = hs.task.new(cmd, options.callback, args)
  else
    task = hs.task.new(cmd, returnCallback, streamCallback, args)
  end
  table.insert(running_processes, { task = task, ttl = mod.getEpoch() + (ttl or 30) })

  if options.quiet then
    logger.f('starting %s in %s', cmd, pwd)
  else
    logger.f('starting %s %s in %s', cmd, hs.inspect(args), pwd)
  end
  task:setWorkingDirectory(pwd)
  ---@type table<string, string>
  local taskEnv = {}
  for key, value in pairs(env) do
    taskEnv[key] = value
  end
  for key, value in pairs(options.env or {}) do
    taskEnv[key] = value
  end
  task:setEnvironment(taskEnv)

  if not task:start() then
    logger.df('failed to start %s', cmd)
  end

  return task
end

return mod
