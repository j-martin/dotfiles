local vocabulary = require 'snippets/vocabulary'

---@type string
local now = '2026-11-10T12:00:00Z'

---@type Snippet[]
local emojis = {
  { trigger = ';:)', text = '🙂', desc = 'smiling emoji' },
  { trigger = ';;)', text = '😉', desc = 'wink emoji' },
}

---@return table
local function existingDocument()
  return {
    appVersion = '0.8.10',
    schema = 'macparakeet.vocabulary',
    version = 1,
    textSnippets = {},
    exportedAt = '2026-11-01T15:46:41Z',
    customWords = {
      { word = 'smiling emoji', replacement = '🙂', isEnabled = false, createdAt = '2026-11-01T15:45:58Z' },
    },
  }
end

return {
  ['build uses the description as the word and the text as the replacement'] = function()
    local document = vocabulary.build(nil, emojis, now)
    local wink = document.customWords[2]
    assert(wink.word == 'wink emoji' and wink.replacement == '😉', 'expected the wink emoji word')
  end,

  ['build creates new words enabled with the current date'] = function()
    local wink = vocabulary.build(nil, emojis, now).customWords[2]
    assert(wink.isEnabled == true and wink.createdAt == now, 'expected an enabled word created now')
  end,

  ['build keeps the creation date and enabled state of existing words'] = function()
    local smiling = vocabulary.build(existingDocument(), emojis, now).customWords[1]
    assert(smiling.createdAt == '2026-11-01T15:45:58Z', 'expected the original creation date')
    assert(smiling.isEnabled == false, 'expected the word to stay disabled')
  end,

  ['build keeps the other fields of the existing document'] = function()
    local document = vocabulary.build(existingDocument(), emojis, now)
    assert(document['appVersion'] == '0.8.10', 'expected the app version to be kept')
  end,

  ['build creates a valid document when none exists'] = function()
    local document = vocabulary.build(nil, emojis, now)
    assert(document.schema == 'macparakeet.vocabulary' and document.version == 1, 'expected the schema and version')
  end,

  ['build only includes snippets with a description'] = function()
    local document = vocabulary.build(nil, { { trigger = ';x', text = 'x' } }, now)
    assert(#document.customWords == 0, 'expected no words')
  end,

  ['hasChanged is false when the words are the same'] = function()
    local document = vocabulary.build(nil, emojis, now)
    local rebuilt = vocabulary.build(document, emojis, '2027-01-01T00:00:00Z')
    assert(not vocabulary.hasChanged(document, rebuilt), 'expected no change')
  end,

  ['hasChanged is true when a word is added'] = function()
    local document = vocabulary.build(existingDocument(), emojis, now)
    assert(vocabulary.hasChanged(existingDocument(), document), 'expected a change')
  end,

  ['hasChanged is true when there is no existing document'] = function()
    assert(vocabulary.hasChanged(nil, vocabulary.build(nil, emojis, now)), 'expected a change')
  end,
}
