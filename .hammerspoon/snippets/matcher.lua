-- Plain Lua helpers for the snippet expander, kept free of `hs` so they can be tested.

---@class Snippet
---@field trigger string Typed text that expands, e.g. ';shrug'.
---@field text string Text inserted in place of the trigger.
---@field desc string|nil Label shown in the picker.
---@field aliases string[]|nil Other triggers for the same text, e.g. ':ss:' for ':sweat_smile:'.
---@field append string|nil Typed after the text when expanding a trigger, e.g. the space that ended it.

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

--- Returns the trigger of `snippet` followed by its aliases.
---@param snippet Snippet
---@return string[]
function mod.triggersOf(snippet)
  ---@type string[]
  local triggers = { snippet.trigger }
  for _, alias in ipairs(snippet.aliases or {}) do
    table.insert(triggers, alias)
  end
  return triggers
end

--- Returns copies of `snippets` with every trigger and alias wrapped by `prefix` and `suffix`, e.g. 'lgtm' -> ';lgtm '.
--- A whitespace suffix is added back after the text when expanding, so ';lgtm ' keeps its space.
---@param snippets Snippet[]
---@param prefix string
---@param suffix string
---@return Snippet[]
function mod.withSeparators(snippets, prefix, suffix)
  ---@type Snippet[]
  local wrapped = {}
  for _, snippet in ipairs(snippets) do
    ---@type string[]|nil
    local aliases = nil
    if snippet.aliases then
      aliases = {}
      for _, alias in ipairs(snippet.aliases) do
        table.insert(aliases, prefix .. alias .. suffix)
      end
    end
    table.insert(wrapped, {
      trigger = prefix .. snippet.trigger .. suffix,
      aliases = aliases,
      text = snippet.text,
      desc = snippet.desc,
      append = suffix:match('^%s+$') and suffix or nil,
    })
  end
  return wrapped
end

--- Returns the length, in characters, of the longest trigger or alias.
---@param snippets Snippet[]
---@return integer
function mod.maxTriggerLength(snippets)
  ---@type integer
  local longest = 0
  for _, snippet in ipairs(snippets) do
    for _, trigger in ipairs(mod.triggersOf(snippet)) do
      longest = math.max(longest, utf8.len(trigger) or #trigger)
    end
  end
  return longest
end

--- Returns how many typed characters to keep: the longest trigger plus the character before it.
---@param snippets Snippet[]
---@return integer
function mod.bufferLength(snippets)
  return mod.maxTriggerLength(snippets) + 1
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

--- Returns whether `trigger` ends `buffer` as its own word, at the start of the buffer or after whitespace.
--- This keeps emoticons like ':/' from expanding inside words, e.g. 'https://'.
---@param buffer string
---@param trigger string
---@return boolean
local function endsWithWord(buffer, trigger)
  if trigger == '' or buffer:sub(-#trigger) ~= trigger then
    return false
  end
  local before = buffer:sub(-#trigger - 1, -#trigger - 1)
  return #buffer == #trigger or before:match('%s') ~= nil
end

--- Returns the snippet with the longest trigger or alias that ends `buffer` as its own word, and that trigger, or nil.
---@param buffer string
---@param snippets Snippet[]
---@return Snippet|nil, string|nil
function mod.findMatch(buffer, snippets)
  ---@type Snippet|nil
  local best = nil
  ---@type string|nil
  local bestTrigger = nil
  for _, snippet in ipairs(snippets) do
    for _, trigger in ipairs(mod.triggersOf(snippet)) do
      if endsWithWord(buffer, trigger) and (bestTrigger == nil or #trigger > #bestTrigger) then
        best = snippet
        bestTrigger = trigger
      end
    end
  end
  return best, bestTrigger
end

return mod
