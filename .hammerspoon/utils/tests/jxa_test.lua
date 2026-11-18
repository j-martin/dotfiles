local jxa = require 'utils/jxa'

---@type table<string, fun()>
local cases = {}

---@param source string
---@return string
local function osascript(source)
  local f = assert(io.popen('/usr/bin/osascript -l JavaScript -e ' .. jxa.shellQuote(jxa.wrap(source)) .. ' 2>&1'))
  ---@type string
  local output = f:read('*a')
  f:close()
  return (output:gsub('%s+$', ''))
end

function cases.jsStringEscapesControlCharacters()
  assert(jxa.jsString('a"b\\c\n\t\1') == '"a\\"b\\\\c\\n\\t\\u0001"', jxa.jsString('a"b\\c\n\t\1'))
end

function cases.wrapReturnsTheCompletionValueAsJson()
  local output = osascript([[
    const quotes = "it's \"quoted\"";
    function main() { return [quotes, 'multi\nline', 'é', 1]; }
    main();
  ]])
  assert(output == [=[[["it's \"quoted\"","multi\nline","é",1]]]=], output)
end

function cases.wrapReturnsNullWithoutCompletionValue()
  local output = osascript('function main() {}; main();')
  assert(output == '[null]', output)
end

return cases
