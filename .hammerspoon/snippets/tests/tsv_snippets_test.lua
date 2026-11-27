local tsvSnippets = require 'snippets/tsv_snippets'

return {
  ['parse reads the text, trigger and description'] = function()
    local snippets = tsvSnippets.parse('jdoe\tjd\tJane Doe\n', 'test.tsv')
    local snippet = snippets[1]
    assert(snippet.text == 'jdoe' and snippet.trigger == 'jd' and snippet.desc == 'Jane Doe', 'expected every field')
  end,

  ['parse leaves an empty trigger nil'] = function()
    local snippets = tsvSnippets.parse('jdoe\t\tJane Doe', 'test.tsv')
    assert(snippets[1].trigger == nil, 'expected no trigger')
  end,

  ['parse reads a line with only the text'] = function()
    local snippets = tsvSnippets.parse('jdoe', 'test.tsv')
    assert(snippets[1].text == 'jdoe' and snippets[1].desc == nil, 'expected only the text')
  end,

  ['parse skips blank lines'] = function()
    local snippets = tsvSnippets.parse('\njdoe\n  \nasmith\n', 'test.tsv')
    assert(#snippets == 2, string.format('expected 2 snippets, got %d', #snippets))
  end,

  ['parse handles windows line endings'] = function()
    local snippets = tsvSnippets.parse('jdoe\tjd\r\n', 'test.tsv')
    assert(snippets[1].trigger == 'jd', string.format('unexpected trigger %q', snippets[1].trigger))
  end,

  ['parse unescapes newlines and tabs'] = function()
    local snippets = tsvSnippets.parse('a\\nb\\tc\\\\n', 'test.tsv')
    assert(snippets[1].text == 'a\nb\tc\\n', string.format('unexpected text %q', snippets[1].text))
  end,

  ['parse reports a line without text'] = function()
    local snippets, errors = tsvSnippets.parse('\tjd\tJane Doe', 'test.tsv')
    assert(#snippets == 0, 'expected no snippet')
    assert(errors[1] == 'test.tsv:1: snippet has no text', string.format('unexpected error %q', errors[1]))
  end,

  ['parse reports a line with too many fields'] = function()
    local _, errors = tsvSnippets.parse('ok\n\njdoe\tjd\tJane\textra', 'test.tsv')
    assert(
      errors[1] == 'test.tsv:3: expected at most 3 tab separated fields',
      string.format('unexpected %q', errors[1])
    )
  end,

  ['encode round trips a multiline text'] = function()
    local text = 'line 1\n\tline 2 \\n\r\n'
    local snippets = tsvSnippets.parse(tsvSnippets.encode(text), 'test.tsv')
    assert(snippets[1].text == text, string.format('unexpected text %q', snippets[1].text))
  end,

  ['encode leaves empty trigger and description'] = function()
    local line = tsvSnippets.encode('jdoe')
    assert(line == 'jdoe\t\t\n', string.format('unexpected line %q', line))
  end,

  ['groupName title cases a kebab-case file name'] = function()
    local name = tsvSnippets.groupName('github-coworkers.tsv')
    assert(name == 'Github Coworkers', string.format('unexpected name %q', name))
  end,

  ['groupName capitalizes a single word'] = function()
    local name = tsvSnippets.groupName('new.tsv')
    assert(name == 'New', string.format('unexpected name %q', name))
  end,

  ['targetFiles puts the default file first'] = function()
    local files = tsvSnippets.targetFiles({ 'a.tsv', 'new.tsv', 'z.tsv' }, 'new.tsv')
    assert(table.concat(files, ',') == 'new.tsv,a.tsv,z.tsv', string.format('unexpected %q', table.concat(files, ',')))
  end,

  ['targetFiles adds the default file when missing'] = function()
    local files = tsvSnippets.targetFiles({ 'a.tsv' }, 'new.tsv')
    assert(table.concat(files, ',') == 'new.tsv,a.tsv', string.format('unexpected %q', table.concat(files, ',')))
  end,

  ['targetFiles sorts the other files'] = function()
    local files = tsvSnippets.targetFiles({ 'z.tsv', 'b.tsv' }, 'new.tsv')
    assert(table.concat(files, ',') == 'new.tsv,b.tsv,z.tsv', string.format('unexpected %q', table.concat(files, ',')))
  end,
}
