-- Spotlight-like confirmation: Enter confirms, Escape cancels.
---@class ConfirmModule
---@field show fun(title: string, details: string|nil, onConfirm: fun())
local mod = {}

--- Shows `title` with `details` underneath and calls `onConfirm` when Enter is pressed.
---@param title string
---@param details string|nil
---@param onConfirm fun()
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
  mod.chooser:queryChangedCallback(function() end)
  mod.chooser:choices({ { text = title, subText = (details or ''):gsub('%s+', ' ') } })
  mod.chooser:show()
end

return mod
