rawset(_G, 'hs', rawget(_G, 'hs') or { logger = { new = function() end } })
local obsidian = require 'apps/obsidian'

---@type number
local time = os.time({ year = 2026, month = 11, day = 17, hour = 8, min = 19, sec = 19 })
---@type string
local prefix = '2026-11-17T08-19-19 - '

return {
  ['fileName starts with the local date-time, dashes replacing colons'] = function()
    assert(obsidian.fileName(time, 'Hello') == prefix .. 'Hello.md')
  end,
  ['fileName replaces characters Obsidian forbids'] = function()
    local name = obsidian.fileName(time, 'Brave Browser — a/b: c [d] #e?')
    assert(name == prefix .. 'Brave Browser — a b c d e.md', name)
  end,
  ['fileName falls back to Draft without a title'] = function()
    assert(obsidian.fileName(time, ' :/ ') == prefix .. 'Draft.md')
  end,
  ['fileName truncates long titles on a character boundary'] = function()
    local name = obsidian.fileName(time, string.rep('é', 150))
    assert(name == prefix .. '' .. string.rep('é', 100) .. '.md')
  end,
  ['content links to the URL'] = function()
    local content = obsidian.content({ title = 'A [b]', url = 'https://e.com/a b)' })
    assert(content == '[A \\[b\\]](https://e.com/a%20b%29)\\n\\n', content)
  end,
  ['content is empty without a URL'] = function()
    assert(obsidian.content({ title = 'iTerm2 — zsh' }) == '')
    assert(obsidian.content(nil) == '')
  end,
}
