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
    if snippet.desc then
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
