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
    local match = matcher.findMatch('x ;signoff', snippets)
    assert(match and match.text == 'Cheers', 'expected the signoff snippet')
  end,

  ['findMatch matches a trigger at the start of the buffer'] = function()
    local match = matcher.findMatch(':)', { { trigger = ':)', text = '🙂' } })
    assert(match and match.text == '🙂', 'expected the smiling emoji')
  end,

  ['findMatch matches a trigger after a newline'] = function()
    local match = matcher.findMatch('ok\n:)', { { trigger = ':)', text = '🙂' } })
    assert(match and match.text == '🙂', 'expected the smiling emoji')
  end,

  ['findMatch ignores a trigger glued to the previous word'] = function()
    assert(matcher.findMatch('https:/', { { trigger = ':/', text = '😕' } }) == nil, 'expected no match in a URL')
  end,

  ['findMatch matches an alias'] = function()
    local sweat = { { trigger = ':sweat_smile:', aliases = { ':ss:' }, text = '😅' } }
    local match, trigger = matcher.findMatch('oops :ss:', sweat)
    assert(match and match.text == '😅', 'expected the sweat smile emoji')
    assert(trigger == ':ss:', string.format('expected the matched trigger ":ss:", got %q', trigger))
  end,

  ['findMatch returns the main trigger when it matched'] = function()
    local _, trigger = matcher.findMatch(' ;shrug', snippets)
    assert(trigger == ';shrug', string.format('expected ";shrug", got %q', trigger))
  end,

  ['maxTriggerLength includes aliases'] = function()
    local long = { { trigger = ':a:', aliases = { ':a_very_long_alias:' }, text = 'a' } }
    assert(matcher.maxTriggerLength(long) == 19, 'expected the alias length')
  end,

  ['withSeparators wraps the trigger'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good' } }, ';', ' ')
    assert(wrapped[1].trigger == ';lgtm ', string.format('expected ";lgtm ", got %q', wrapped[1].trigger))
  end,

  ['withSeparators wraps the aliases'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', aliases = { 'lg' }, text = 'Looks good' } }, ';', ' ')
    assert(wrapped[1].aliases[1] == ';lg ', string.format('expected ";lg ", got %q', wrapped[1].aliases[1]))
  end,

  ['withSeparators keeps the text and description'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good', desc = 'LGTM' } }, ';', ' ')
    assert(wrapped[1].text == 'Looks good' and wrapped[1].desc == 'LGTM', 'expected the text and description')
  end,

  ['withSeparators keeps a whitespace suffix to add back after the text'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good' } }, ';', ' ')
    assert(wrapped[1].append == ' ', string.format('expected " ", got %q', wrapped[1].append))
  end,

  ['withSeparators does not add back a suffix that is not whitespace'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good' } }, ';', ';')
    assert(wrapped[1].append == nil, 'expected nothing to add back')
  end,

  ['findMatch expands a separated trigger once the space is typed'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good' } }, ';', ' ')
    assert(matcher.findMatch('ok ;lgtm', wrapped) == nil, 'expected no match before the space')
    assert(matcher.findMatch('ok ;lgtm ', wrapped), 'expected a match after the space')
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

  ['bufferLength keeps room for the character before the longest trigger'] = function()
    assert(matcher.bufferLength(snippets) == 9, 'expected 9')
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
