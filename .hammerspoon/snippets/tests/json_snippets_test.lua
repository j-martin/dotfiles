local jsonSnippets = require 'snippets/json_snippets'

return {
  ['parse keeps snippets with a text'] = function()
    local group = jsonSnippets.parse({ { desc = 'Jane Doe', text = 'jdoe' } }, 'test.json')
    assert(#group.snippets == 1 and group.snippets[1].text == 'jdoe', 'expected the jdoe snippet')
  end,

  ['parse reads the name of a group'] = function()
    local group = jsonSnippets.parse({ name = 'GitHub - Coworkers', snippets = { { text = 'jdoe' } } }, 'test.json')
    assert(group.name == 'GitHub - Coworkers', string.format('unexpected name %q', group.name))
  end,

  ['parse keeps the snippets of a group'] = function()
    local group = jsonSnippets.parse({ name = 'GitHub - Coworkers', snippets = { { text = 'jdoe' } } }, 'test.json')
    assert(#group.snippets == 1 and group.snippets[1].text == 'jdoe', 'expected the jdoe snippet')
  end,

  ['parse leaves an array unnamed'] = function()
    local group = jsonSnippets.parse({ { text = 'jdoe' } }, 'test.json')
    assert(group.name == nil, 'expected no name')
  end,

  ['parse reports a name that is not a string'] = function()
    local group, errors = jsonSnippets.parse({ name = 1, snippets = { { text = 'jdoe' } } }, 'test.json')
    assert(group.name == nil and #errors == 1, 'expected an error and no name')
  end,

  ['parse reports a snippet without text'] = function()
    local group, errors = jsonSnippets.parse({ { desc = 'Jane Doe' } }, 'test.json')
    assert(#group.snippets == 0, 'expected no snippet')
    assert(errors[1] == 'test.json: snippet 1 has no text', string.format('unexpected error %q', errors[1]))
  end,

  ['parse reports a trigger that is not a string'] = function()
    local _, errors = jsonSnippets.parse({ { trigger = 1, text = 'jdoe' } }, 'test.json')
    assert(#errors == 1, 'expected an error')
  end,

  ['parse keeps the valid snippets next to invalid ones'] = function()
    local group = jsonSnippets.parse({ { text = '' }, { text = 'jdoe' } }, 'test.json')
    assert(#group.snippets == 1 and group.snippets[1].text == 'jdoe', 'expected only the jdoe snippet')
  end,

  ['parse reports content that is neither a group nor an array'] = function()
    local group, errors = jsonSnippets.parse('jdoe', 'test.json')
    assert(#group.snippets == 0 and #errors == 1, 'expected a single error')
  end,
}
