-- Runs JavaScript for Automation (JXA) scripts with `/usr/bin/osascript`, instead of `hs.osascript.javascript`.
-- `hs.osascript.javascript` runs them inside Hammerspoon, where the JavaScriptCore memory of every run is never
-- released, growing Hammerspoon by ~1 MB per run. A separate process gives that memory back when it exits.
local logger = hs and hs.logger.new('jxa', 'info')

---@alias JxaCallback fun(ok: boolean, result: any, err: string|nil)

---@class JxaModule
---@field osascript string
---@field ttl number
---@field jsString fun(value: string): string
---@field shellQuote fun(value: string): string
---@field wrap fun(source: string): string
---@field decode fun(ok: boolean, output: string): boolean, any, string|nil
---@field run fun(source: string): boolean, any, string|nil
---@field start fun(source: string, callback: JxaCallback|nil, ttl: number|nil): hs.task
local mod = {}

mod.osascript = '/usr/bin/osascript'

-- Seconds before an asynchronous script is terminated.
mod.ttl = 30

---@type table<string, string>
local jsEscapes = { ['\\'] = '\\\\', ['"'] = '\\"', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

--- Returns `value` as a double quoted JavaScript string literal.
---@param value string
---@return string
function mod.jsString(value)
  ---@type string
  local escaped = value:gsub('[%c\\"]', function(char)
    return jsEscapes[char] or string.format('\\u%04x', char:byte())
  end)
  return '"' .. escaped .. '"'
end

--- Returns `value` single quoted for a POSIX shell.
---@param value string
---@return string
function mod.shellQuote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

--- Wraps `source` to print its completion value, like `hs.osascript.javascript` returns it, as a one element JSON array.
---@param source string
---@return string
function mod.wrap(source)
  return 'JSON.stringify([(0, eval)(' .. mod.jsString(source) .. ')])'
end

--- Decodes the output of a wrapped script into `ok, result, err`.
---@param ok boolean
---@param output string
---@return boolean ok
---@return any result
---@return string|nil err
function mod.decode(ok, output)
  output = output:gsub('%s+$', '')
  if not ok then
    return false, nil, output
  end
  local json = output:match('[^\n]*$')
  local decoded, values = pcall(hs.json.decode, json)
  if not decoded or type(values) ~= 'table' then
    return false, nil, 'Could not decode the script output: ' .. output
  end
  return true, values[1], nil
end

--- Runs `source` synchronously, and returns `ok, result, err` with the completion value of the script as `result`.
---@param source string
---@return boolean ok
---@return any result
---@return string|nil err
function mod.run(source)
  local output, status = require('utils/process').execute(
    mod.osascript .. ' -l JavaScript -e ' .. mod.shellQuote(mod.wrap(source)) .. ' 2>&1'
  )
  local ok, result, err = mod.decode(status == true, output)
  if not ok then
    logger.ef('Script failed: %s', err)
  end
  return ok, result, err
end

--- Runs `source` asynchronously, terminated after `ttl` seconds, and calls `callback` like `mod.run` returns.
---@param source string
---@param callback JxaCallback|nil
---@param ttl number|nil
---@return hs.task
function mod.start(source, callback, ttl)
  ttl = ttl or mod.ttl
  local task = require('utils/process').start(mod.osascript, { '-l', 'JavaScript', '-e', mod.wrap(source) }, nil, ttl, {
    quiet = true,
    callback = function(exitCode, stdOut, stdErr)
      local ok, result, err = mod.decode(exitCode == 0, exitCode == 0 and stdOut or (stdOut .. stdErr))
      if not ok then
        logger.ef('Script failed: %s', err)
      end
      if callback then
        callback(ok, result, err)
      end
    end,
  })
  hs.timer.doAfter(ttl, function()
    if task:isRunning() then
      logger.wf('Script still running after %d seconds, terminating it', ttl)
      task:terminate()
    end
  end)
  return task
end

return mod
