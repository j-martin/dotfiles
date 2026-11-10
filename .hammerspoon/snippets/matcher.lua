-- Plain Lua helpers for the snippet expander, kept free of `hs` so they can be tested.

---@class Snippet
---@field trigger string Typed text that expands, e.g. ';shrug'.
---@field text string Text inserted in place of the trigger.
---@field desc string|nil Label shown in the picker.

---@class SnippetMatcherModule
local mod = {}

--- Returns the public snippets with the private ones added, a private snippet replacing a public one with the same trigger.
---@param public Snippet[]
---@param private Snippet[]
---@return Snippet[]
function mod.merge(public, private)
  ---@type table<string, integer>
  local indexByTrigger = {}
  ---@type Snippet[]
  local merged = {}
  for _, list in ipairs({ public, private }) do
    for _, snippet in ipairs(list) do
      local index = indexByTrigger[snippet.trigger]
      if index then
        merged[index] = snippet
      else
        table.insert(merged, snippet)
        indexByTrigger[snippet.trigger] = #merged
      end
    end
  end
  return merged
end

--- Returns the length, in characters, of the longest trigger.
---@param snippets Snippet[]
---@return integer
function mod.maxTriggerLength(snippets)
  ---@type integer
  local longest = 0
  for _, snippet in ipairs(snippets) do
    longest = math.max(longest, utf8.len(snippet.trigger) or #snippet.trigger)
  end
  return longest
end

--- Returns `buffer` with `char` appended, keeping only its last `maxLength` characters.
---@param buffer string
---@param char string
---@param maxLength integer
---@return string
function mod.push(buffer, char, maxLength)
  local result = buffer .. char
  local excess = (utf8.len(result) or #result) - maxLength
  if excess > 0 then
    result = result:sub(utf8.offset(result, excess + 1))
  end
  return result
end

--- Returns `buffer` without its last character.
---@param buffer string
---@return string
function mod.pop(buffer)
  local lastStart = utf8.offset(buffer, -1)
  if not lastStart then
    return ''
  end
  return buffer:sub(1, lastStart - 1)
end

--- Returns the snippet with the longest trigger that ends `buffer`, or nil.
---@param buffer string
---@param snippets Snippet[]
---@return Snippet|nil
function mod.findMatch(buffer, snippets)
  ---@type Snippet|nil
  local best = nil
  for _, snippet in ipairs(snippets) do
    local trigger = snippet.trigger
    local endsBuffer = trigger ~= '' and buffer:sub(-#trigger) == trigger
    if endsBuffer and (best == nil or #trigger > #best.trigger) then
      best = snippet
    end
  end
  return best
end

return mod
