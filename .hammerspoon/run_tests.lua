-- Runs every <dir>/tests/*_test.lua file outside Hammerspoon: `mise run test`
package.path = './?.lua;' .. package.path

---@type integer
local failures = 0
---@type integer
local total = 0

---@type file*
local listing = assert(io.popen("find . -path ./Spoons -prune -o -path '*/tests/*_test.lua' -print | sort"))
for path in listing:lines() do
  ---@type table<string, fun()>
  local cases = dofile(path)
  ---@type string[]
  local names = {}
  for name in pairs(cases) do
    table.insert(names, name)
  end
  table.sort(names)
  for _, name in ipairs(names) do
    total = total + 1
    local ok, err = pcall(cases[name])
    if not ok then
      failures = failures + 1
      print(string.format('FAIL %s: %s\n  %s', path, name, err))
    end
  end
end
listing:close()

print(string.format('%d tests, %d failures', total, failures))
os.exit(failures == 0 and 0 or 1)
