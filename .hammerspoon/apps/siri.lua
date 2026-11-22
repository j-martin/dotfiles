local process = require 'utils/process'

---@class SiriApp
---@field path string
---@field dialogBundleID string
---@field trigger fun()
local mod = {}

mod.path = '/System/Applications/Siri.app'
--- The Siri dialog is owned by this process, not by Siri.app itself.
mod.dialogBundleID = 'com.apple.campo'

--- Returns the visible Siri dialog windows, if any.
---@return hs.window[]
local function dialogWindows()
  ---@type hs.window[]
  local windows = {}
  for _, app in ipairs(hs.application.applicationsForBundleID(mod.dialogBundleID)) do
    for _, win in ipairs(app:allWindows()) do
      if win:isVisible() then
        table.insert(windows, win)
      end
    end
  end
  return windows
end

--- Toggles Siri: closes the dialog when shown, otherwise invokes Siri (fire and forget).
function mod.trigger()
  local windows = dialogWindows()
  if #windows > 0 then
    for _, win in ipairs(windows) do
      win:close()
    end
    return
  end
  process.start('/usr/bin/open', { mod.path })
end

return mod
