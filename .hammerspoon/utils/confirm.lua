-- Spotlight-like confirmation: Enter confirms, Escape cancels.
---@class ConfirmModule
---@field chooser hs.chooser|nil
local mod = {}

---@class ConfirmOption
---@field text string
---@field subText string|nil

--- Shows `choices` in the shared chooser, restoring the focused window, and calls `onChoice` with the picked one.
---@param placeholder string Shown in the empty input.
---@param choices table[]
---@param onChoice fun(choice: table, query: string)
---@return hs.chooser
local function open(placeholder, choices, onChoice)
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
      onChoice(choice, chooser:query() or '')
    end
  end)
  mod.chooser = chooser
  chooser:bgDark(true)
  chooser:rows(#choices)
  chooser:placeholderText(placeholder)
  chooser:choices(choices)
  chooser:query('')
  return chooser
end

--- Shows `title` with `details` underneath and calls `onConfirm` with the typed text when Enter is pressed.
---@param title string
---@param details string|nil
---@param placeholder string Shown in the empty input.
---@param onConfirm fun(input: string)
function mod.prompt(title, details, placeholder, onConfirm)
  local chooser = open(placeholder, { { text = title, subText = (details or ''):gsub('%s+', ' ') } }, function(_, query)
    onConfirm(query)
  end)
  chooser:queryChangedCallback(function() end)
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

--- Shows `options`, the first one selected, and calls `onChoose` with the index of the picked one. Escape picks none.
---@param placeholder string Shown in the empty input, e.g. the question.
---@param options ConfirmOption[]
---@param onChoose fun(index: integer)
function mod.choose(placeholder, options, onChoose)
  ---@type table[]
  local choices = {}
  for index, option in ipairs(options) do
    table.insert(choices, { text = option.text, subText = option.subText, index = index })
  end
  open(placeholder, choices, function(choice)
    onChoose(choice.index)
  end):show()
end

return mod
