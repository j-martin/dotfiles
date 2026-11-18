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
    local append = matcher.appendFor(wrapped[1], wrapped[1].trigger)
    assert(append == ' ', string.format('expected " ", got %q', append))
  end,

  ['withSeparators does not add back a suffix that is not whitespace'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good' } }, ';', ';')
    assert(matcher.appendFor(wrapped[1], wrapped[1].trigger) == '', 'expected nothing to add back')
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

  ['privateGroups wraps a list of snippets in a group'] = function()
    local groups = matcher.privateGroups({ { trigger = 'a', text = 'A' } })
    assert(#groups == 1 and #groups[1].snippets == 1, 'expected a single group of one snippet')
  end,

  ['privateGroups keeps a single group'] = function()
    local groups = matcher.privateGroups({ name = 'Personal', snippets = {} })
    assert(#groups == 1 and groups[1].name == 'Personal', 'expected the Personal group')
  end,

  ['privateGroups keeps a list of groups'] = function()
    local groups = matcher.privateGroups({ { name = 'Personal', snippets = {} }, { name = 'Work', snippets = {} } })
    assert(#groups == 2 and groups[2].name == 'Work', 'expected the Personal and Work groups')
  end,

  ['privateGroups returns no group for nil'] = function()
    assert(#matcher.privateGroups(nil) == 0, 'expected no group')
  end,

  ['merge appends new private snippets'] = function()
    local merged = matcher.merge(snippets, { { trigger = ';new', text = 'New' } })
    assert(#merged == 4, string.format('expected 4 snippets, got %d', #merged))
  end,

  ['render replaces the placeholders'] = function()
    local values = { date = '2026-11-14', time = '08:52', clipboard = 'x' }
    local text, cursorBack = matcher.render('{date:short} {time:short} `{clipboard}` ${HOME}', values)
    assert(text == '2026-11-14 08:52 `x` ${HOME}', string.format('unexpected %q', text))
    assert(cursorBack == 0, 'expected no cursor move')
  end,

  ['render quotes every line of the clipboard'] = function()
    local text = matcher.render('{clipboard:quote}', { date = '', time = '', clipboard = 'a\r\n\nb\n\n' })
    assert(text == '> a\n>\n> b', string.format('unexpected %q', text))
  end,

  ['render removes the cursor and counts the characters after it'] = function()
    local _, cursorBack = matcher.render('use {cursor}?é', { date = '', time = '', clipboard = '' })
    assert(cursorBack == 2, string.format('expected 2, got %d', cursorBack))
  end,

  ['render removes the trailing lines'] = function()
    local text = matcher.render('a  \nb\n\n  \n', { date = '', time = '', clipboard = '' })
    assert(text == 'a  \nb', string.format('unexpected %q', text))
  end,

  ['render returns the trailing spaces apart, since apps trim them when pasting'] = function()
    local text, _, trailing = matcher.render('a \t\n', { date = '', time = '', clipboard = '' })
    assert(text == 'a' and trailing == ' \t', string.format('unexpected %q and %q', text, trailing))
  end,

  ['render counts the trailing spaces after the cursor'] = function()
    local _, cursorBack = matcher.render('[{cursor}](x) ', { date = '', time = '', clipboard = '' })
    assert(cursorBack == 5, string.format('expected 5, got %d', cursorBack))
  end,

  ['render keeps the cursor in the trailing spaces'] = function()
    local text, cursorBack, trailing = matcher.render('a {cursor} ', { date = '', time = '', clipboard = '' })
    assert(text == 'a' and trailing == '  ', string.format('unexpected %q and %q', text, trailing))
    assert(cursorBack == 1, string.format('expected 1, got %d', cursorBack))
  end,

  ['render counts the characters after the cursor without the trailing lines'] = function()
    local _, cursorBack = matcher.render('cat <<EOF > {cursor}\n\nEOF\n\n', { date = '', time = '', clipboard = '' })
    assert(cursorBack == 5, string.format('expected 5, got %d', cursorBack))
  end,

  ['render keeps the cursor at the end when it is in the trailing lines'] = function()
    local text, cursorBack = matcher.render('a\n{cursor}\n', { date = '', time = '', clipboard = '' })
    assert(text == 'a', string.format('unexpected %q', text))
    assert(cursorBack == 0, string.format('expected 0, got %d', cursorBack))
  end,

  ['snippets without a trigger are kept but never match'] = function()
    local pickerOnly = { { text = 'a' }, { text = 'b' } }
    local wrapped = matcher.withSeparators(pickerOnly, ';', ' ')
    local merged = matcher.merge(wrapped, {})
    assert(#merged == 2, string.format('expected 2 snippets, got %d', #merged))
    assert(matcher.findMatch('a ', merged) == nil, 'expected no match')
    assert(matcher.maxTriggerLength(merged) == 0, 'expected no trigger length')
  end,

  ['flatten wraps each group with its own prefix and suffix'] = function()
    local groups = {
      { prefix = 'm', suffix = '  ', snippets = { { trigger = '1', text = 'one' } } },
      { snippets = { { trigger = 'lgtm', text = 'Looks good' } } },
    }
    local snippets = matcher.flatten(groups, ';', ' ')
    assert(snippets[1].trigger == 'm1  ', string.format('expected "m1  ", got %q', snippets[1].trigger))
    assert(snippets[2].trigger == ';lgtm ', string.format('expected ";lgtm ", got %q', snippets[2].trigger))
  end,

  ['flatten lets a snippet override its group separators with empty strings'] = function()
    local groups = {
      {
        prefix = 'gh',
        suffix = ' ',
        snippets = {
          { trigger = 'lgtm', text = 'Looks good', prefix = '', suffix = '' },
        },
      },
    }
    local snippet = matcher.flatten(groups, ';', ' ')[1]
    assert(snippet.trigger == 'lgtm', string.format('expected "lgtm", got %q', snippet.trigger))
    assert(matcher.appendFor(snippet, snippet.trigger) == '', 'expected raw trigger behavior')
  end,

  ['flatten lets a later group replace a snippet with the same wrapped trigger'] = function()
    local groups = {
      { snippets = { { trigger = 'sig', text = 'Public' } } },
      { snippets = { { trigger = 'sig', text = 'Private' } } },
    }
    local snippets = matcher.flatten(groups, ';', ' ')
    assert(#snippets == 1 and snippets[1].text == 'Private', 'expected the private snippet')
  end,

  ['findMatch expands after a vim insert command only in vim apps'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good' } }, ';', ' ')
    assert(matcher.findMatch('kkC;lgtm ', wrapped, true), 'expected a match after C')
    assert(matcher.findMatch('jjciw;lgtm ', wrapped, true), 'expected a match after ciw')
    assert(matcher.findMatch('kkC;lgtm ', wrapped) == nil, 'expected no match outside vim apps')
  end,

  ['findMatch needs a vim insert command before a glued trigger in vim apps'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good' } }, ';', ' ')
    assert(matcher.findMatch('kkx;lgtm ', wrapped, true) == nil, 'expected no match after x')
  end,

  ['findMatch expands after a visual mode change in vim apps'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'lgtm', text = 'Looks good' } }, ';', ' ')
    assert(matcher.findMatch('Vjjc;lgtm ', wrapped, true), 'expected a match after Vjjc')
    assert(matcher.findMatch('V}S;lgtm ', wrapped, true), 'expected a match after V}S')
    assert(matcher.findMatch('v$c;lgtm ', wrapped, true), 'expected a match after v$c')
    assert(matcher.findMatch('Vjjd;lgtm ', wrapped, true) == nil, 'expected no match after Vjjd')
  end,

  ['findMatch still needs a word start without a prefix or suffix'] = function()
    local wrapped = matcher.withSeparators({ { trigger = ':/', text = '😕' } }, '', '')
    assert(matcher.findMatch('https:/', wrapped) == nil, 'expected no match in a URL')
  end,

  ['withSeparators adds back a single space for a longer whitespace suffix'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'np', text = 'You are welcome.' } }, '', '  ')
    local append = matcher.appendFor(wrapped[1], wrapped[1].trigger)
    assert(append == ' ', string.format('expected " ", got %q', append))
  end,

  ['flatten labels snippets with their group name'] = function()
    local groups = { { name = 'GitHub', snippets = { { desc = 'Re-review', text = 'Can you review?' } } } }
    local label = matcher.label(matcher.flatten(groups, ';', ' ')[1])
    assert(label == 'GitHub - Re-review', string.format('expected "GitHub - Re-review", got %q', label))
  end,

  ['matchesQuery needs every word, including group aliases'] = function()
    local groups = { { name = 'GitHub', aliases = { 'gh' }, snippets = { { desc = 'Re-review', text = 'Can you?' } } } }
    local snippet = matcher.flatten(groups, ';', ' ')[1]
    assert(matcher.matchesQuery(snippet, 'GH review'), 'expected the alias and name to match')
    assert(not matcher.matchesQuery(snippet, 'gh merge'), 'expected no match for a missing word')
  end,

  ['label uses the text on a single line without a description'] = function()
    local label = matcher.label({ trigger = 'ph', text = '#!/usr/bin/env python3\n# coding\n' })
    assert(label == '#!/usr/bin/env python3 # coding', string.format('unexpected %q', label))
  end,

  ['withSeparators accepts any sentence suffix and adds back the one typed'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'suod', text = 'sudo' } }, '', { ' ', '.', ',' })
    local snippet, trigger = matcher.findMatch('use suod.', wrapped)
    assert(snippet and trigger, 'expected a match ending with a period')
    assert(matcher.appendFor(snippet, trigger) == '.', 'expected the period to be added back')
    assert(#snippet.shown == 1 and snippet.shown[1] == 'suod ', 'expected only the first suffix to be shown')
  end,

  ['withSeparators replaces a suffix name with its list'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'suod', text = 'sudo' } }, '', 'sentence')
    local snippet, trigger = matcher.findMatch('use suod!', wrapped)
    assert(snippet and trigger == 'suod!', 'expected a match ending with an exclamation mark')
    assert(matcher.appendFor(snippet, trigger) == '!', 'expected the exclamation mark to be added back')
  end,

  ['splitHeader finds the header on the first line'] = function()
    local header, text = matcher.splitHeader('# {"trigger":"x"}\nbody\n')
    assert(header == '{"trigger":"x"}', string.format('unexpected header %q', header))
    assert(text == 'body\n', string.format('unexpected text %q', text))
  end,

  ['splitHeader finds the header anywhere in the top comment block'] = function()
    local content = '#!/usr/bin/env python3\n# -*- coding: utf-8 -*-\n# {"trigger":"hpython"}\nprint()\n'
    local header, text = matcher.splitHeader(content)
    assert(header == '{"trigger":"hpython"}', string.format('unexpected header %q', header))
    assert(text == '#!/usr/bin/env python3\n# -*- coding: utf-8 -*-\nprint()\n', string.format('unexpected %q', text))
  end,

  ['splitHeader handles a header on the last line without a newline'] = function()
    local header, text = matcher.splitHeader('#!/bin/sh\n# {"trigger":"x"}')
    assert(header == '{"trigger":"x"}' and text == '#!/bin/sh\n', string.format('unexpected %q', text))
  end,

  ['splitHeader ignores a header after the top comment block'] = function()
    assert(matcher.splitHeader('#!/bin/sh\necho\n# {"trigger":"x"}\n') == nil, 'expected no header')
  end,

  ['findMatch needs a word start with sentence suffixes, punctuation counts as one'] = function()
    local wrapped = matcher.withSeparators({ { trigger = 'suod', text = 'sudo' } }, '', { ' ', '.' })
    assert(matcher.findMatch('xsuod ', wrapped) == nil, 'expected no match inside a word')
    assert(matcher.findMatch('(suod ', wrapped), 'expected a match after a parenthesis')
    assert(matcher.findMatch('ésuod ', wrapped) == nil, 'expected no match after a multibyte letter')
  end,

  ['groups lists the group names in order of first appearance with their snippet counts'] = function()
    local groups = matcher.groups({
      { text = 'a', group = 'GitHub', keywords = { 'gh' } },
      { text = 'b', group = 'Email' },
      { text = 'c', group = 'GitHub', keywords = { 'gh' } },
    })
    assert(#groups == 2, string.format('expected 2 groups, got %d', #groups))
    assert(groups[1].name == 'GitHub' and groups[1].count == 2, 'expected GitHub with 2 snippets first')
    assert(groups[1].keywords[1] == 'gh', 'expected the GitHub aliases')
    assert(groups[2].name == 'Email' and groups[2].count == 1, 'expected Email with 1 snippet second')
  end,

  ['groups puts the snippets without a group in the ungrouped group'] = function()
    local groups = matcher.groups({ { text = 'a' } })
    assert(groups[1].name == matcher.ungrouped, string.format('expected %q, got %q', matcher.ungrouped, groups[1].name))
  end,

  ['inGroup returns the snippets of the group'] = function()
    local list =
      matcher.inGroup({ { text = 'a', group = 'GitHub' }, { text = 'b' }, { text = 'c', group = 'GitHub' } }, 'GitHub')
    assert(#list == 2 and list[1].text == 'a' and list[2].text == 'c', 'expected the two GitHub snippets')
  end,

  ['inGroup returns the snippets without a group for the ungrouped group'] = function()
    local list = matcher.inGroup({ { text = 'a', group = 'GitHub' }, { text = 'b' } }, matcher.ungrouped)
    assert(#list == 1 and list[1].text == 'b', 'expected the snippet without a group')
  end,

  ['groupMatchesQuery matches every word in the name or aliases, ignoring case'] = function()
    local group = { name = 'GitHub - Team - nestoca', count = 1, keywords = { 'gh' } }
    assert(matcher.groupMatchesQuery(group, 'gh team'), 'expected a match on the alias and name')
    assert(not matcher.groupMatchesQuery(group, 'email'), 'expected no match')
  end,

  ['label leaves out the group when asked'] = function()
    local label = matcher.label({ text = 'x', desc = 'Re-review', group = 'GitHub' }, true)
    assert(label == 'Re-review', string.format('expected "Re-review", got %q', label))
  end,
}
