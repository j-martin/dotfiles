local mod = {}

mod.name = 'Google Meet'

--- Toggles the microphone, even when Google Meet is not focused.
function mod.toggleMute()
  hs.eventtap.keyStroke('cmd', 'd', 200, hs.application.get(mod.name))
end

return mod
