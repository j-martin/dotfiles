-- Plain Lua parsing and encoding of `text<TAB>trigger<TAB>description` snippet lines, kept free of `hs` so it can be tested.
-- Backslashes, tabs and newlines in a field are written as `\\`, `\t` and `\n`.

---@class TsvSnippetsModule
local mod = {}

---@type table<string, string>
local unescapes = { ['\\'] = '\\', t = '\t', n = '\n', r = '\r' }

---@type table<string, string>
local escapes = { ['\\'] = '\\\\', ['\t'] = '\\t', ['\n'] = '\\n', ['\r'] = '\\r' }

--- Returns `field` with its `\\`, `\t`, `\n` and `\r` escapes replaced, an unknown escape is kept as is.
---@param field string
---@return string
function mod.unescape(field)
  return (field:gsub('\\(.?)', function(char)
    return unescapes[char] or ('\\' .. char)
  end))
end

--- Returns `field` with its backslashes, tabs and newlines escaped.
---@param field string
---@return string
function mod.escape(field)
  return (field:gsub('[\\\t\n\r]', escapes))
end

--- Returns `field` unescaped, nil when empty.
---@param field string|nil
---@return string|nil
local function optional(field)
  if field == nil or field == '' then
    return nil
  end
  return mod.unescape(field)
end

--- Returns the snippets of the TSV `content`, skipping blank lines, and a message per invalid line.
---@param content string
---@param source string Shown in the messages, e.g. the file path.
---@return Snippet[] snippets
---@return string[] errors
function mod.parse(content, source)
  ---@type Snippet[]
  local snippets = {}
  ---@type string[]
  local errors = {}
  ---@type integer
  local number = 0
  for line in (content .. '\n'):gmatch('(.-)\r?\n') do
    number = number + 1
    if line:match('%S') then
      ---@type string[]
      local fields = {}
      for field in (line .. '\t'):gmatch('(.-)\t') do
        table.insert(fields, field)
      end
      local text = optional(fields[1])
      if text == nil then
        table.insert(errors, string.format('%s:%d: snippet has no text', source, number))
      elseif #fields > 3 then
        table.insert(errors, string.format('%s:%d: expected at most 3 tab separated fields', source, number))
      else
        table.insert(snippets, { text = text, trigger = optional(fields[2]), desc = optional(fields[3]) })
      end
    end
  end
  return snippets, errors
end

--- Returns the group name of a TSV `file`, its kebab-case name in title case, e.g. 'Github Coworkers' for 'github-coworkers.tsv'.
---@param file string
---@return string
function mod.groupName(file)
  local name = file:gsub('%.tsv$', ''):gsub('%-', ' '):gsub('(%w)(%w*)', function(first, rest)
    return first:upper() .. rest
  end)
  return name
end

--- Returns the files a snippet can be added to: `default` first, even when not in `files`, then the others sorted.
---@param files string[] Existing TSV file names, e.g. 'github-coworkers.tsv'.
---@param default string The file added to by default, e.g. 'new.tsv'.
---@return string[]
function mod.targetFiles(files, default)
  ---@type string[]
  local others = {}
  for _, file in ipairs(files) do
    if file ~= default then
      table.insert(others, file)
    end
  end
  table.sort(others)
  table.insert(others, 1, default)
  return others
end

--- Returns the TSV line of `text` with an optional `trigger` and `desc`, ending with a newline.
---@param text string
---@param trigger string|nil
---@param desc string|nil
---@return string
function mod.encode(text, trigger, desc)
  return table.concat({ mod.escape(text), mod.escape(trigger or ''), mod.escape(desc or '') }, '\t') .. '\n'
end

return mod
