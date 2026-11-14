-- Plain Lua helpers for the snippet expander, kept free of `hs` so they can be tested.

---@class Snippet
---@field trigger string|nil Typed text that expands, e.g. ';shrug', nil for snippets only in the picker.
---@field text string Text inserted in place of the trigger, see `mod.render` for its placeholders.
---@field desc string|nil Label shown in the picker, the text on a single line when nil.
---@field prefix string|nil Overrides the snippet group's prefix, including with an empty string.
---@field suffix string|string[]|nil Overrides the snippet group's suffix, including with an empty string.
---@field skipVocabulary boolean|nil Excludes the snippet from the MacParakeet vocabulary export.
---@field aliases string[]|nil Other triggers for the same text, e.g. ':ss:' for ':sweat_smile:'.
---@field suffixes string[]|nil Suffixes added back after the text when they end the typed trigger, see `mod.appendFor`.
---@field shown string[]|nil Triggers shown in the picker, without the ones for other sentence suffixes.
---@field group string|nil Name of its group, set by `mod.flatten`.
---@field keywords string[]|nil Aliases of its group, only searched in the picker, set by `mod.flatten`.

---@class SnippetGroup
---@field prefix string|nil Typed before every trigger of the group, the default prefix when nil.
---@field suffix string|string[]|nil Typed after every trigger of the group to expand it, the default suffix when nil.
--- A list allows any of them, a name in `mod.namedSuffixes` is replaced by its list, e.g. 'sentence'.
---@field name string|nil Shown before the description of every snippet in the picker, e.g. 'GitHub'.
---@field aliases string[]|nil Other names of the group, only searched in the picker, e.g. 'gh'.
---@field snippets Snippet[]

---@class SnippetMatcherModule
local mod = {}

-- Suffix lists a group or snippet can use by name, e.g. `suffix = 'sentence'`.
---@type table<string, string[]>
mod.namedSuffixes = {
  -- Characters that can follow a word in a sentence, the one typed is added back after the text.
  sentence = { ' ', '.', ',', ':', ';', '!', '?', ')', ']', '}', '"' },
}

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
      local index = snippet.trigger and indexByTrigger[snippet.trigger]
      if index then
        merged[index] = snippet
      else
        table.insert(merged, snippet)
        if snippet.trigger then
          indexByTrigger[snippet.trigger] = #merged
        end
      end
    end
  end
  return merged
end

--- Returns the trigger of `snippet` followed by its aliases, empty for snippets only in the picker.
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

--- Returns `suffix` as a list, e.g. ' ' -> { ' ' }.
---@param suffix string|string[]
---@return string[]
local function suffixList(suffix)
  if type(suffix) == 'table' then
    return suffix
  end
  return { suffix }
end

--- Returns copies of `snippets` with every trigger and alias wrapped by `prefix` and `suffix`, e.g. 'lgtm' -> ';lgtm '.
--- With a list of suffixes, e.g. 'sentence', each one ends a trigger: 'suod ', 'suod.', ...
--- See `mod.appendFor` for the suffix added back after the text.
---@param snippets Snippet[]
---@param prefix string
---@param suffix string|string[]
---@return Snippet[]
function mod.withSeparators(snippets, prefix, suffix)
  ---@type Snippet[]
  local wrapped = {}
  for _, snippet in ipairs(snippets) do
    local snippetPrefix = snippet.prefix ~= nil and snippet.prefix or prefix
    local snippetSuffix = snippet.suffix ~= nil and snippet.suffix or suffix
    snippetSuffix = mod.namedSuffixes[snippetSuffix] or snippetSuffix
    local suffixes = suffixList(snippetSuffix)
    ---@type string[]
    local triggers = {}
    ---@type string[]
    local shown = {}
    for _, trigger in ipairs(mod.triggersOf(snippet)) do
      table.insert(shown, snippetPrefix .. trigger .. suffixes[1])
      for _, end_ in ipairs(suffixes) do
        table.insert(triggers, snippetPrefix .. trigger .. end_)
      end
    end
    ---@type string[]|nil
    local addedBack = nil
    if type(snippetSuffix) == 'table' then
      addedBack = snippetSuffix
    elseif snippetSuffix:match('^%s+$') then
      addedBack = { snippetSuffix }
    end
    table.insert(wrapped, {
      trigger = triggers[1],
      aliases = #triggers > 1 and { table.unpack(triggers, 2) } or nil,
      shown = #shown > 0 and shown or nil,
      text = snippet.text,
      desc = snippet.desc,
      suffixes = addedBack,
    })
  end
  return wrapped
end

--- Returns what to type after the text of `snippet` when `trigger` expanded it, '' for nothing.
--- The suffix that ended the trigger is added back, a whitespace one as a single character: 'np  ' -> ' ', 'suod.' -> '.'.
---@param snippet Snippet
---@param trigger string
---@return string
function mod.appendFor(snippet, trigger)
  ---@type string
  local best = ''
  for _, suffix in ipairs(snippet.suffixes or {}) do
    if #suffix > #best and trigger:sub(-#suffix) == suffix then
      best = suffix
    end
  end
  if best:match('^%s+$') then
    return best:sub(1, 1)
  end
  return best
end

--- Returns the snippets of `groups`, each wrapped by its group prefix and suffix or the defaults.
--- A later snippet replaces an earlier one with the same wrapped trigger.
---@param groups SnippetGroup[]
---@param prefix string Default prefix.
---@param suffix string Default suffix.
---@return Snippet[]
function mod.flatten(groups, prefix, suffix)
  ---@type Snippet[]
  local snippets = {}
  for _, group in ipairs(groups) do
    local wrapped = mod.withSeparators(group.snippets, group.prefix or prefix, group.suffix or suffix)
    for _, snippet in ipairs(wrapped) do
      snippet.group = group.name
      snippet.keywords = group.aliases
    end
    snippets = mod.merge(snippets, wrapped)
  end
  return snippets
end

--- Returns the label of `snippet` in the picker, e.g. 'GitHub - Re-review'.
---@param snippet Snippet
---@return string
function mod.label(snippet)
  local name = snippet.desc or snippet.text:gsub('%s+', ' '):match('^%s*(.-)%s*$')
  if snippet.group then
    return snippet.group .. ' - ' .. name
  end
  return name
end

--- Returns whether every word of `query` is in the label, triggers, group aliases or text of `snippet`, ignoring case.
---@param snippet Snippet
---@param query string
---@return boolean
function mod.matchesQuery(snippet, query)
  local haystack = table
    .concat({
      mod.label(snippet),
      table.concat(mod.triggersOf(snippet), ' '),
      table.concat(snippet.keywords or {}, ' '),
      snippet.text,
    }, ' ')
    :lower()
  for word in query:lower():gmatch('%S+') do
    if not haystack:find(word, 1, true) then
      return false
    end
  end
  return true
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

-- Vim normal-mode commands entering insert mode, matched at the end of the keys typed before a trigger.
-- The buffer only resets on escape, so it also holds the normal-mode keys typed before them, e.g. 'kkjciw'.
---@type string[]
local vimInsertCommands = {
  '[iaIAoOsSC]$', -- i, a, o, gi, ...
  'c[ia]?%a$', -- cc, cw, ciw, caw, cb, ...
  'c[tTfF].$', -- ct., cf), ...
}

--- Returns whether `keys` end with a vim command entering insert mode, e.g. 'kkciw'.
---@param keys string
---@return boolean
function mod.endsWithVimInsert(keys)
  for _, pattern in ipairs(vimInsertCommands) do
    if keys:match(pattern) then
      return true
    end
  end
  return false
end

--- Returns whether `trigger` ends `buffer` as its own word, at the start of the buffer or after a non-word character.
--- This keeps emoticons like ':/' from expanding inside words, e.g. 'https://', but allows '(suod '.
---@param buffer string
---@param trigger string
---@param vim boolean|nil Also matches after the normal-mode keys of a vim command entering insert mode, e.g. 'ciw;lgtm '.
---@return boolean
local function endsWithWord(buffer, trigger, vim)
  if trigger == '' or buffer:sub(-#trigger) ~= trigger then
    return false
  end
  ---@type string
  local before = buffer:sub(1, -#trigger - 1)
  -- Bytes above 127 are part of multibyte letters, e.g. 'é'.
  ---@type string
  local word = before:match('[%w_\128-\255]*$')
  return word == '' or (vim == true and mod.endsWithVimInsert(word))
end

--- Returns the snippet with the longest trigger or alias that ends `buffer` as its own word, and that trigger, or nil.
---@param buffer string
---@param snippets Snippet[]
---@param vim boolean|nil Whether the app uses vim bindings, see `endsWithWord`.
---@return Snippet|nil, string|nil
function mod.findMatch(buffer, snippets, vim)
  ---@type Snippet|nil
  local best = nil
  ---@type string|nil
  local bestTrigger = nil
  for _, snippet in ipairs(snippets) do
    for _, trigger in ipairs(mod.triggersOf(snippet)) do
      if endsWithWord(buffer, trigger, vim) and (bestTrigger == nil or #trigger > #bestTrigger) then
        best = snippet
        bestTrigger = trigger
      end
    end
  end
  return best, bestTrigger
end

---@class SnippetValues
---@field date string Replaces '{date:short}'.
---@field time string Replaces '{time:short}'.
---@field clipboard string Replaces '{clipboard}'.

--- Returns `text` with its placeholders replaced, without '{cursor}', and how many characters follow '{cursor}'.
--- Moving the cursor left by that count puts it where '{cursor}' was, 0 without it.
---@param text string
---@param values SnippetValues
---@return string, integer
function mod.render(text, values)
  local replacements = {
    ['{date:short}'] = values.date,
    ['{time:short}'] = values.time,
    ['{clipboard}'] = values.clipboard,
  }
  local rendered = text:gsub('{[%w:]+}', function(placeholder)
    return replacements[placeholder]
  end)
  local cursorStart, cursorEnd = rendered:find('{cursor}', 1, true)
  if not cursorStart then
    return rendered, 0
  end
  local after = rendered:sub(cursorEnd + 1)
  return rendered:sub(1, cursorStart - 1) .. after, utf8.len(after) or #after
end

--- Returns the JSON header of a file snippet and its content without the header line, or nil without a header.
--- The header is the first `# {...}` line of the `#` comment block starting the file, e.g. after a shebang.
---@param content string
---@return string|nil, string|nil
function mod.splitHeader(content)
  ---@type integer
  local position = 1
  while position <= #content do
    local lineEnd = content:find('\n', position, true) or #content
    local line = content:sub(position, lineEnd):gsub('\r?\n$', '')
    if not line:match('^%s*#') then
      return nil, nil
    end
    local header = line:match('^%s*#%s*({.*})%s*$')
    if header then
      return header, content:sub(1, position - 1) .. content:sub(lineEnd + 1)
    end
    position = lineEnd + 1
  end
  return nil, nil
end

return mod
