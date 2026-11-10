local matcher = require 'snippets/matcher'

---@type Snippet[]
local snippets = {
  { trigger = ';sig', text = 'Signature' },
  { trigger = ';signoff', text = 'Cheers' },
  { trigger = ';shrug', text = '¯\\_(ツ)_/¯' },
}

return {
  ['findMatch returns the snippet whose trigger ends the buffer'] = function()
    local match = matcher.findMatch('hello ;shrug', snippets)
    assert(match and match.text == '¯\\_(ツ)_/¯', 'expected the shrug snippet')
  end,

  ['findMatch prefers the longest trigger'] = function()
    local match = matcher.findMatch('x;signoff', snippets)
    assert(match and match.text == 'Cheers', 'expected the signoff snippet')
  end,

  ['findMatch returns nil when no trigger ends the buffer'] = function()
    assert(matcher.findMatch(';sig ', snippets) == nil, 'expected no match')
  end,

  ['findMatch treats triggers literally'] = function()
    local dotted = { { trigger = '.d', text = 'dot' } }
    assert(matcher.findMatch('xd', dotted) == nil, 'expected no match for a pattern character')
  end,

  ['push appends the character'] = function()
    local buffer = matcher.push(';sh', 'r', 10)
    assert(buffer == ';shr', string.format('expected ";shr", got %q', buffer))
  end,

  ['push keeps only the last maxLength characters'] = function()
    local buffer = matcher.push('abcde', 'f', 3)
    assert(buffer == 'def', string.format('expected "def", got %q', buffer))
  end,

  ['push counts multibyte characters as one'] = function()
    local buffer = matcher.push('aé', 'ç', 2)
    assert(buffer == 'éç', string.format('expected "éç", got %q', buffer))
  end,

  ['pop removes the last character'] = function()
    local buffer = matcher.pop(';shé')
    assert(buffer == ';sh', string.format('expected ";sh", got %q', buffer))
  end,

  ['maxTriggerLength returns the longest trigger length'] = function()
    assert(matcher.maxTriggerLength(snippets) == 8, 'expected 8')
  end,

  ['merge lets private snippets replace public ones with the same trigger'] = function()
    local merged = matcher.merge(snippets, { { trigger = ';sig', text = 'Private' } })
    local match = matcher.findMatch(';sig', merged)
    assert(#merged == 3, string.format('expected 3 snippets, got %d', #merged))
    assert(match and match.text == 'Private', 'expected the private snippet')
  end,

  ['merge appends new private snippets'] = function()
    local merged = matcher.merge(snippets, { { trigger = ';new', text = 'New' } })
    assert(#merged == 4, string.format('expected 4 snippets, got %d', #merged))
  end,
}
