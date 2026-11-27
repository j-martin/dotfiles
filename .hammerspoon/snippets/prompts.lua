-- Fills in snippets whose text is a function: each prompt is a picker taking typed text and/or predefined choices.
-- Only `mod.ask` uses `hs`, the other functions are tested outside Hammerspoon.

---@alias SnippetChoiceInput string|{ text: string, subText: string|nil, value: string|nil }

---@class SnippetPrompt
---@field name string Key of the answer in the values given to the snippet text function.
---@field label string|nil Placeholder of the picker, the name when nil.
---@field choices SnippetChoiceInput[]|(fun(values: table<string, string>): SnippetChoiceInput[])|nil Predefined answers,
--- a function is given the previous answers. Without choices, the typed text is the answer.
---@field strict boolean|nil Only accepts one of the choices, not the typed text.

---@class SnippetChoice
---@field text string Shown in the picker.
---@field subText string|nil
---@field value string Answer given to the snippet text function, the text when not set.

---@class SnippetPromptsModule
local mod = {}

-- Kept at module level so it is not garbage collected.
---@type hs.chooser|nil
local chooser = nil

--- Returns the choices of `prompt`, calling its `choices` function with `values`, or nil and an error when it fails.
---@param prompt SnippetPrompt
---@param values table<string, string> Answers of the previous prompts.
---@return SnippetChoice[]|nil choices
---@return string|nil error
function mod.choicesOf(prompt, values)
  local inputs = prompt.choices or {}
  if type(inputs) == 'function' then
    local ok, result = pcall(inputs, values)
    if not ok or type(result) ~= 'table' then
      return nil, string.format('Choices of %q failed: %s', prompt.name, ok and 'expected a list' or result)
    end
    inputs = result
  end
  ---@type SnippetChoice[]
  local choices = {}
  for _, input in ipairs(inputs) do
    if type(input) == 'table' then
      table.insert(choices, { text = input.text, subText = input.subText, value = input.value or input.text })
    else
      table.insert(choices, { text = tostring(input), value = tostring(input) })
    end
  end
  return choices
end

--- Returns whether every word of `query` is in `haystack`, ignoring case.
---@param haystack string
---@param query string
---@return boolean
local function matchesWords(haystack, query)
  haystack = haystack:lower()
  for word in query:lower():gmatch('%S+') do
    if not haystack:find(word, 1, true) then
      return false
    end
  end
  return true
end

--- Returns the picker rows of `prompt` for `query`: the choices matching it, then the typed text,
--- unless the prompt is strict, the query is empty while there are choices, or a choice is exactly the query.
---@param prompt SnippetPrompt
---@param choices SnippetChoice[]
---@param query string
---@return SnippetChoice[]
function mod.rows(prompt, choices, query)
  ---@type SnippetChoice[]
  local rows = {}
  ---@type boolean
  local exact = false
  for _, choice in ipairs(choices) do
    if matchesWords(choice.text .. ' ' .. (choice.subText or ''), query) then
      table.insert(rows, { text = choice.text, subText = choice.subText, value = choice.value })
      exact = exact or choice.text == query
    end
  end
  if not prompt.strict and not exact and (query ~= '' or #choices == 0) then
    table.insert(rows, { text = query, subText = 'Use the typed text, ⏎ to confirm', value = query })
  end
  return rows
end

--- Returns the placeholder of the picker of `prompt`, e.g. 'Repository (1/2)'.
---@param prompt SnippetPrompt
---@param index integer
---@param count integer
---@return string
function mod.placeholder(prompt, index, count)
  local label = prompt.label or prompt.name
  if count > 1 then
    return string.format('%s (%d/%d)', label, index, count)
  end
  return label
end

--- Returns the text of `snippet`, calling its text function with `values`, or nil and an error when it fails.
--- With prompts, a text string has its `{{ name }}` placeholders replaced by the answers, e.g.
--- 'https://github.com/{{ repo }}/pull/{{ number }}'. Names of no prompt are kept, e.g. for Helm templates.
---@param snippet Snippet
---@param values table<string, string>
---@return string|nil text
---@return string|nil error
function mod.fill(snippet, values)
  if type(snippet.text) ~= 'function' then
    local text = snippet.text --[[@as string]]
    if not snippet.prompts then
      return text
    end
    return (text:gsub('{{%s*([%w_]+)%s*}}', values))
  end
  local ok, result = pcall(snippet.text, values)
  if not ok or type(result) ~= 'string' then
    return nil, string.format('Snippet %q failed: %s', snippet.desc or '', ok and 'expected a string' or result)
  end
  return result
end

--- Shows a picker per prompt, in order, and calls `onDone` with the answers by prompt name, or nil when cancelled.
---@param prompts SnippetPrompt[]
---@param onDone fun(values: table<string, string>|nil)
function mod.ask(prompts, onDone)
  ---@type table<string, string>
  local values = {}
  ---@param index integer
  local function askAt(index)
    local prompt = prompts[index]
    if not prompt then
      onDone(values)
      return
    end
    local choices, err = mod.choicesOf(prompt, values)
    if not choices then
      hs.alert.show('Snippets - ' .. err)
      onDone(nil)
      return
    end
    if chooser then
      chooser:delete()
    end
    chooser = hs.chooser.new(function(row)
      if not row then
        onDone(nil)
        return
      end
      values[prompt.name] = row.value
      -- Shown once this picker is closed.
      hs.timer.doAfter(0, function()
        askAt(index + 1)
      end)
    end)
    chooser:bgDark(true)
    chooser:placeholderText(mod.placeholder(prompt, index, #prompts))
    chooser:queryChangedCallback(function(query)
      if chooser then
        chooser:choices(mod.rows(prompt, choices, query))
      end
    end)
    chooser:choices(mod.rows(prompt, choices, ''))
    chooser:show()
  end
  askAt(1)
end

return mod
