local logger = hs.logger.new('messages', 'info')
local selection = require 'selection'
local confirm = require 'utils/confirm'
local privateConfig = require 'utils/private_config'

local mod = {}

local previewLength = 300

local function escapeAppleScript(text)
  return (text:gsub('\\', '\\\\'):gsub('"', '\\"'))
end

local function send(recipient, text)
  local script = string.format(
    [[
    tell application "Messages"
      set targetService to 1st account whose service type = iMessage
      set targetParticipant to participant "%s" of targetService
      send "%s" to targetParticipant
    end tell
  ]],
    escapeAppleScript(recipient),
    escapeAppleScript(text)
  )
  local ok, _, details = hs.osascript.applescript(script)
  if not ok then
    logger.ef('Could not send the iMessage to %s: %s', recipient, hs.inspect(details))
    hs.alert.show('iMessage failed to send')
    return
  end
  hs.alert.show('iMessage sent to ' .. recipient)
end

-- Sends the selected text, or the clipboard when nothing is selected, to the private config `iMessageRecipient` after a confirmation prompt.
function mod.sendSelection()
  local recipient = privateConfig.get('iMessageRecipient')
  if not recipient then
    hs.alert.show("No 'iMessageRecipient' in " .. privateConfig.path)
    return
  end

  local text = selection.getSelectedText()
  if text == '' then
    text = hs.pasteboard.readString()
  end
  if not text or text == '' then
    hs.alert.show('Nothing selected and clipboard is empty')
    return
  end

  local preview = text
  if #preview > previewLength then
    preview = preview:sub(1, previewLength) .. '…'
  end

  confirm.show('💬 Send to ' .. recipient .. '?', preview, function()
    -- Deferred so the chooser closes before the blocking AppleScript runs
    mod.sendTimer = hs.timer.doAfter(0.1, function()
      send(recipient, text)
    end)
  end)
end

return mod
