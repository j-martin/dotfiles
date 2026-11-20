-- Spotlight-like confirmation: Enter confirms, Escape cancels.
---@class ConfirmModule
---@field chooser hs.chooser|nil
local mod = {}

--- Shows `title` with `details` underneath and calls `onConfirm` with the typed text when Enter is pressed.
---@param title string
---@param details string|nil
---@param placeholder string Shown in the empty input.
---@param onConfirm fun(input: string)
function mod.prompt(title, details, placeholder, onConfirm)
  local window = hs.window.focusedWindow()
  if mod.chooser then
    mod.chooser:delete()
  end
  ---@type hs.chooser
  local chooser
  chooser = hs.chooser.new(function(choice)
    if window then
      window:focus()
    end
    if choice then
      onConfirm(chooser:query() or '')
    end
  end)
  mod.chooser = chooser
  chooser:bgDark(true)
  chooser:rows(1)
  chooser:placeholderText(placeholder)
  chooser:queryChangedCallback(function() end)
  chooser:choices({ { text = title, subText = (details or ''):gsub('%s+', ' ') } })
  chooser:query('')
  chooser:show()
end

--- Shows `title` with `details` underneath and calls `onConfirm` when Enter is pressed.
---@param title string
---@param details string|nil
---@param onConfirm fun()
function mod.show(title, details, onConfirm)
  mod.prompt(title, details, '⏎ to confirm, esc to cancel', function()
    onConfirm()
  end)
end

return mod
