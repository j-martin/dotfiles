local logger = hs.logger.new('messages', 'info')

local mod = {}

-- Config example:
-- ~/.private/hammerspoon.json
-- {
--   "iMessageRecipient": "+15145550000"
-- }
local privateConfigPath = os.getenv('HOME') .. '/.private/hammerspoon.json'

local previewLength = 300

local function readRecipient()
  if not hs.fs.attributes(privateConfigPath) then
    return nil
  end
  local config = hs.json.read(privateConfigPath)
  return config and config.iMessageRecipient
end

local function escapeAppleScript(text)
  return (text:gsub('\\', '\\\\'):gsub('"', '\\"'))
end

local function send(recipient, text)
  local script = string.format([[
    tell application "Messages"
      set targetService to 1st account whose service type = iMessage
      set targetParticipant to participant "%s" of targetService
      send "%s" to targetParticipant
    end tell
  ]], escapeAppleScript(recipient), escapeAppleScript(text))
  local ok, _, details = hs.osascript.applescript(script)
  if not ok then
    logger.ef('Could not send the iMessage to %s: %s', recipient, hs.inspect(details))
    hs.alert.show('iMessage failed to send')
    return
  end
  hs.alert.show('iMessage sent to ' .. recipient)
end

-- Sends the clipboard content to the `iMessageRecipient` from ~/.private/hammerspoon.json after a confirmation prompt.
function mod.sendClipboard()
  local recipient = readRecipient()
  if not recipient then
    hs.alert.show("No 'iMessageRecipient' in " .. privateConfigPath)
    return
  end

  local text = hs.pasteboard.readString()
  if not text or text == '' then
    hs.alert.show('Clipboard is empty')
    return
  end

  local preview = text
  if #preview > previewLength then
    preview = preview:sub(1, previewLength) .. '…'
  end

  hs.focus()
  local answer = hs.dialog.blockAlert('Send clipboard to ' .. recipient .. '?', preview, 'Send', 'Cancel')
  if answer ~= 'Send' then
    return
  end
  send(recipient, text)
end

return mod
