--- Based on Pause/unpause playing music
---- Diego Zamboni <diego@zzamboni.org>
--- Needs Hammerspoon with audio-device watcher capabilities
--- (0.9.43 or later), but checks for the features so it won't crash.

local mod = {}

local audio = require("hs.audiodevice")

local devs = {}

-- Per-device watcher to detect headphones in/out
function audiodevwatch(dev_uid, event_name, event_scope, event_element)
  logger.df("Audiodevwatch args: %s, %s, %s, %s", dev_uid, event_name, event_scope, event_element)
  dev = audio.findDeviceByUID(dev_uid)
  if event_name == 'jack' then
    if dev:jackConnected() then
      logger.d("Headphones plugged")
      notify("Headphones plugged")
    else
      logger.d("Headphones disconnected")
      audio.defaultOlaunchOrCycleFocusutputDevice():setVolume(0)
    end
  end
end

function mod.init()
  for i, dev in ipairs(audio.allOutputDevices()) do
    if dev.watcherCallback ~= nil then
      logger.df("Setting up watcher for audio device %s (UID %s)", dev:name(), dev:uid())
      devs[dev:uid()]=dev:watcherCallback(audiodevwatch)
      devs[dev:uid()]:watcherStart()
    else
      logger.w("Skipping audio device watcher setup because you have an older version of Hammerspoon")
    end
  end
end

return mod
