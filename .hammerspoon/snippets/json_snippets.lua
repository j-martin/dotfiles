-- Plain Lua validation of snippets decoded from JSON files, kept free of `hs` so it can be tested.

---@class JsonSnippetsModule
local mod = {}

--- Returns the group of `decoded`, either a `SnippetGroup` object or an array of snippets, keeping its valid
--- snippets, and a message per invalid entry.
---@param decoded any The decoded JSON content.
---@param source string Shown in the messages, e.g. the file path.
---@return SnippetGroup group
---@return string[] errors
function mod.parse(decoded, source)
  ---@type SnippetGroup
  local group = { snippets = {} }
  ---@type string[]
  local errors = {}
  if type(decoded) ~= 'table' then
    return group, { string.format('%s: expected a snippet group or an array of snippets', source) }
  end
  local list = decoded
  if decoded.snippets ~= nil then
    if type(decoded.snippets) ~= 'table' then
      return group, { string.format('%s: snippets is not an array', source) }
    end
    if decoded.name ~= nil and type(decoded.name) ~= 'string' then
      table.insert(errors, string.format('%s: name is not a string', source))
    else
      group.name = decoded.name
    end
    group.aliases = decoded.aliases
    group.prefix = decoded.prefix
    group.suffix = decoded.suffix
    list = decoded.snippets
  end
  for index, snippet in ipairs(list) do
    if type(snippet) ~= 'table' or type(snippet.text) ~= 'string' or snippet.text == '' then
      table.insert(errors, string.format('%s: snippet %d has no text', source, index))
    elseif snippet.trigger ~= nil and type(snippet.trigger) ~= 'string' then
      table.insert(errors, string.format('%s: snippet %d has a trigger that is not a string', source, index))
    elseif snippet.desc ~= nil and type(snippet.desc) ~= 'string' then
      table.insert(errors, string.format('%s: snippet %d has a desc that is not a string', source, index))
    else
      table.insert(group.snippets, snippet)
    end
  end
  return group, errors
end

return mod
