local emojis = require 'snippets/emojis'
local matcher = require 'snippets/matcher'

return {
  ['every emoji has a trigger, a text and a description'] = function()
    for index, emoji in ipairs(emojis) do
      assert(
        emoji.trigger ~= '' and emoji.text ~= '' and emoji.desc ~= nil,
        string.format('emoji %d is incomplete', index)
      )
    end
  end,

  ['triggers and aliases are unique'] = function()
    ---@type table<string, boolean>
    local seen = {}
    for _, emoji in ipairs(emojis) do
      for _, trigger in ipairs(matcher.triggersOf(emoji)) do
        assert(not seen[trigger], string.format('duplicate trigger %s', trigger))
        seen[trigger] = true
      end
    end
  end,

  ['descriptions are unique'] = function()
    ---@type table<string, boolean>
    local seen = {}
    for _, emoji in ipairs(emojis) do
      assert(not seen[emoji.desc], string.format('duplicate description %s', emoji.desc))
      seen[emoji.desc] = true
    end
  end,
}
