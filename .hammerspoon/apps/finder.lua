local mod = {}

mod.name = 'Finder'

--- Returns the name and URL of the first selected file.
function mod.context()
  local ok, file = hs.osascript.javascript(
    "const f = Application('" .. mod.name .. "').selection()[0]; f ? [f.name(), f.url()] : null"
  )
  if not ok or type(file) ~= 'table' then
    return nil
  end
  return { title = file[1], url = file[2] }
end

return mod
