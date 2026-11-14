-- Builds the MacParakeet vocabulary (spoken word -> replacement) from snippets, kept free of `hs` so it can be tested.

---@class MacParakeetWord
---@field word string Spoken words, the snippet description.
---@field replacement string Inserted text, the snippet text.
---@field isEnabled boolean
---@field createdAt string ISO 8601 date.

---@class MacParakeetVocabulary
---@field schema string
---@field version integer
---@field customWords MacParakeetWord[]
---@field textSnippets table[]
---@field exportedAt string|nil

---@class SnippetVocabularyModule
local mod = {}

--- Returns `existing` with its custom words replaced by the snippets that have a description.
--- Words already present keep their creation date and enabled state.
---@param existing MacParakeetVocabulary|nil
---@param snippets Snippet[]
---@param now string ISO 8601 date used for new words.
---@return MacParakeetVocabulary
function mod.build(existing, snippets, now)
  ---@type MacParakeetVocabulary
  local document = { schema = 'macparakeet.vocabulary', version = 1, customWords = {}, textSnippets = {} }
  ---@type table<string, MacParakeetWord>
  local previousByWord = {}
  if existing then
    for key, value in pairs(existing) do
      document[key] = value
    end
    for _, word in ipairs(existing.customWords or {}) do
      previousByWord[word.word] = word
    end
  end

  ---@type MacParakeetWord[]
  local words = {}
  for _, snippet in ipairs(snippets) do
    if snippet.desc and not snippet.skipVocabulary then
      local previous = previousByWord[snippet.desc]
      table.insert(words, {
        word = snippet.desc,
        replacement = snippet.text,
        isEnabled = previous == nil or previous.isEnabled,
        createdAt = previous and previous.createdAt or now,
      })
    end
  end
  document.customWords = words
  return document
end

-- Keys written first, in this order, the others follow sorted, so rewriting the file only shows real changes.
---@type string[]
local keyOrder = {
  'schema',
  'version',
  'appVersion',
  'exportedAt',
  'customWords',
  'textSnippets',
  'word',
  'replacement',
  'isEnabled',
  'createdAt',
}
---@type table<string, integer>
local keyRank = {}
for index, key in ipairs(keyOrder) do
  keyRank[key] = index
end

---@param a string
---@param b string
---@return boolean
local function compareKeys(a, b)
  local rankA, rankB = keyRank[a] or math.huge, keyRank[b] or math.huge
  if rankA ~= rankB then
    return rankA < rankB
  end
  return a < b
end

---@param value string
---@return string
local function encodeString(value)
  local escaped = value:gsub('[%c"\\]', function(char)
    local named = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    return named[char] or string.format('\\u%04x', char:byte())
  end)
  return '"' .. escaped .. '"'
end

---@param value any
---@param indent string
---@return string
local function encodeValue(value, indent)
  local kind = type(value)
  if kind == 'string' then
    return encodeString(value)
  elseif kind == 'number' then
    return math.type(value) == 'integer' and tostring(value) or string.format('%.17g', value)
  elseif kind == 'boolean' then
    return tostring(value)
  elseif kind ~= 'table' then
    return 'null'
  end
  local inner = indent .. '  '
  ---@type string[]
  local parts = {}
  -- Empty tables are written as arrays, e.g. 'textSnippets'.
  if next(value) == nil or #value > 0 then
    if next(value) == nil then
      return '[]'
    end
    for _, item in ipairs(value) do
      table.insert(parts, inner .. encodeValue(item, inner))
    end
    return '[\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. ']'
  end
  ---@type string[]
  local keys = {}
  for key in pairs(value) do
    table.insert(keys, tostring(key))
  end
  table.sort(keys, compareKeys)
  for _, key in ipairs(keys) do
    table.insert(parts, inner .. encodeString(key) .. ': ' .. encodeValue(value[key], inner))
  end
  return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}'
end

--- Returns `document` as pretty JSON with its keys in a stable order, ending with a newline.
---@param document MacParakeetVocabulary
---@return string
function mod.encode(document)
  return encodeValue(document, '') .. '\n'
end

--- Returns whether the custom words of `updated` differ from the ones of `existing`.
---@param existing MacParakeetVocabulary|nil
---@param updated MacParakeetVocabulary
---@return boolean
function mod.hasChanged(existing, updated)
  if existing == nil or existing.customWords == nil then
    return true
  end
  if #existing.customWords ~= #updated.customWords then
    return true
  end
  for index, word in ipairs(updated.customWords) do
    local previous = existing.customWords[index]
    for _, field in ipairs({ 'word', 'replacement', 'isEnabled', 'createdAt' }) do
      if previous[field] ~= word[field] then
        return true
      end
    end
  end
  return false
end

return mod
