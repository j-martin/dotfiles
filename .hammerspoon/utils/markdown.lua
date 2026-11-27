---@class MarkdownModule
---@field quote fun(text: string): string
---@field link fun(title: string, url: string): string
local mod = {}

--- Returns a Markdown link to `url`, escaping brackets and collapsing whitespace in `title`, and percent-encoding
--- whitespace and closing parentheses in `url`: ('A [b]', 'https://e.com/a b)') -> '[A \[b\]](https://e.com/a%20b%29)'.
---@param title string
---@param url string
---@return string
function mod.link(title, url)
  ---@type string
  local escapedTitle = title:gsub('%s+', ' '):gsub('([%[%]])', '\\%1')
  ---@type string
  local escapedUrl = url:gsub('%s', '%%20'):gsub('%)', '%%29')
  return '[' .. escapedTitle .. '](' .. escapedUrl .. ')'
end

--- Returns `text` as a Markdown quote, without its trailing newlines: 'a\n\nb\n' -> '> a\n>\n> b'.
---@param text string
---@return string
function mod.quote(text)
  ---@type string[]
  local lines = {}
  for line in (text:gsub('\r\n', '\n'):gsub('\n+$', '') .. '\n'):gmatch('(.-)\n') do
    table.insert(lines, line == '' and '>' or '> ' .. line)
  end
  return table.concat(lines, '\n')
end

return mod
