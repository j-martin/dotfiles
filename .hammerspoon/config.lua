-- Global config, applied before loading the other modules.

---@class Config
---@field appResponseTimeout number Seconds a running application has to answer before being considered not responding.
---@field appSwitchTimeout number Seconds a running application has to become frontmost once focused.
---@field appLaunchTimeout number Seconds a launched application has to become frontmost.
---@field snippetPrefix string Typed before a snippet trigger.
---@field snippetSuffix string Typed after a snippet trigger to expand it.
---@field vimApps string[] Bundle IDs of apps with vim bindings, where snippets also expand right after an insert command.
---@field snippetSound string|nil System sound played after expanding a snippet, e.g. 'Tink', nil for none.
---@field snippetJsonPath string Directory of generated `*.json` snippet files, each a snippet group.
---@field macParakeetVocabularyPath string Vocabulary generated from `snippets/library/emojis.lua`, see `snippets/vocabulary.lua`.
local mod = {}

-- Limits how long Hammerspoon waits on stuck applications when switching to them, see `utils/app_guard.lua`.
mod.appResponseTimeout = 0.5
mod.appSwitchTimeout = 2
mod.appLaunchTimeout = 5

-- Typing `;<trigger> ` (with the space) replaces it with its text, hyper + 5 (or hyper + space, s) lists them all.
-- The prefix avoids expanding normal words, the space allows triggers that start like others.
-- Snippets are in `snippets/library/<category>.lua` and files under the matching category directory, private ones in config.
-- These are the defaults, a file can set its own `prefix` and `suffix`, e.g. the emojis use neither.
mod.snippetPrefix = ';'
mod.snippetSuffix = ' '
-- Names are the files in /System/Library/Sounds, without the extension.
mod.snippetSound = 'Tink'
-- Their normal-mode keys, e.g. `ciw`, stay in the typed buffer, so a trigger right after them still expands.
mod.vimApps = {
  'org.gnu.Emacs',
  'org.gnu.EmacsClient',
  'com.jetbrains.goland',
  'com.microsoft.VSCode',
}

-- Generated snippets kept out of the repository, e.g. by `~/.bin/hammerspoon-snippets-generator`.
mod.snippetJsonPath = os.getenv('HOME') .. '/.local/share/hammerspoon/snippets'

-- Emoji words for MacParakeet dictation, regenerated on load from `snippets/library/emojis.lua`.
mod.macParakeetVocabularyPath = os.getenv('HOME') .. '/.config/macparakeet/vocabulary.json'

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
