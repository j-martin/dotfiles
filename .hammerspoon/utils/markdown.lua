---@class MarkdownModule
---@field quote fun(text: string): string
local mod = {}

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
