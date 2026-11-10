-- Global config, applied before loading the other modules.

---@class Config
---@field appResponseTimeout number Seconds a running application has to answer before being considered not responding.
---@field appSwitchTimeout number Seconds a running application has to become frontmost once focused.
---@field appLaunchTimeout number Seconds a launched application has to become frontmost.
---@field snippets Snippet[] Public snippets, merged with `snippets` from the private config, see `snippets/init.lua`.
local mod = {}

-- Limits how long Hammerspoon waits on stuck applications when switching to them, see `utils/app_guard.lua`.
mod.appResponseTimeout = 0.5
mod.appSwitchTimeout = 2
mod.appLaunchTimeout = 5

-- Typing a trigger replaces it with its text, hyper + s lists them all.
-- Triggers start with ';' to avoid expanding while typing normal words.
mod.snippets = {
  { trigger = ';shrug', text = '¯\\_(ツ)_/¯', desc = 'Shrug' },
  { trigger = ';tflip', text = '(╯°□°)╯︵ ┻━┻', desc = 'Table flip' },
  { trigger = ';lgtm', text = 'Looks good to me 👍', desc = 'LGTM' },
}

-- Alerts, e.g. mode and kinesis alerts.
-- https://www.hammerspoon.org/docs/hs.alert.html#defaultStyle
hs.alert.defaultStyle['textSize'] = 20
hs.alert.defaultStyle['radius'] = 10

-- Seconds hotkey messages are shown.
-- https://www.hammerspoon.org/docs/hs.hotkey.html#alertDuration
hs.hotkey.alertDuration = 2.5

-- Allows finding applications by their localized names, e.g. with `launchOrFocus`.
-- https://www.hammerspoon.org/docs/hs.application.html#enableSpotlightForNameSearches
hs.application.enableSpotlightForNameSearches(true)

-- Moves and resizes windows instantly, and limits the wait on unresponsive apps.
-- https://www.hammerspoon.org/docs/hs.window.html#animationDuration
-- https://www.hammerspoon.org/docs/hs.window.html#timeout
hs.window.animationDuration = 0
hs.window.timeout(1)

-- Grid used to position windows.
-- https://www.hammerspoon.org/docs/hs.grid.html
hs.grid.ui.textSize = 15
hs.grid.GRIDWIDTH = 10
hs.grid.GRIDHEIGHT = 4
hs.grid.MARGINX = 0
hs.grid.MARGINY = 0

-- Installs the `hs` command line tool, used to send commands to Hammerspoon.
-- https://www.hammerspoon.org/docs/hs.ipc.html
require 'hs.ipc'
if not hs.ipc.cliStatus('/opt/homebrew', true) then
  hs.ipc.cliInstall('/opt/homebrew')
end

return mod
