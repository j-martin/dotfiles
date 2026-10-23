-- Spotlight-like confirmation: Enter confirms, Escape cancels.
local mod = {}

--- Shows `title` with `details` underneath and calls `onConfirm` when Enter is pressed.
function mod.show(title, details, onConfirm)
  local window = hs.window.focusedWindow()
  if mod.chooser then
    mod.chooser:delete()
  end
  mod.chooser = hs.chooser.new(function(choice)
    if window then
      window:focus()
    end
    if choice then
      onConfirm()
    end
  end)
  mod.chooser:bgDark(true)
  mod.chooser:rows(1)
  mod.chooser:placeholderText('⏎ to confirm, esc to cancel')
  -- Ignore typing so the single row is never filtered out
  mod.chooser:queryChangedCallback(function() end)
  mod.chooser:choices({ { text = title, subText = (details or ''):gsub('%s+', ' ') } })
  mod.chooser:show()
end

return mod
