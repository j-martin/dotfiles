---@class StackTable
---@field _et any[]
---@field push fun(...: any)
---@field pop fun(num: number|nil): any
---@field getn fun(): number
---@field list fun()
Stack = {}

-- Create a Table with stack functions
---@return StackTable
function Stack:Create()
  -- stack table
  local t = {}
  -- entry table
  t._et = {}

  -- push a value on to the stack
  function t:push(...)
    if ... then
      local targs = { ... }
      -- add values
      for _, v in ipairs(targs) do
        table.insert(self._et, v)
      end
    end
  end

  -- pop a value from the stack
  function t:pop(num)
    local num = num or 1

    local entries = {}

    for i = 1, num do
      if #self._et ~= 0 then
        table.insert(entries, self._et[#self._et])
        table.remove(self._et)
      else
        break
      end
    end
    return table.unpack(entries)
  end

  -- get entries
  function t:getn()
    return #self._et
  end

  -- list values
  function t:list()
    for i, v in pairs(self._et) do
      print(i, v)
    end
  end
  return t
end
