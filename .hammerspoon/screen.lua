local mod = {}

function mod.setBrightness(value)
  local script = [[
    tell application "System Preferences"
      if it is running then
        quit
      end if
    end tell
    delay 0.2
    activate application "System Preferences"
    tell application "System Events"
      tell process "System Preferences"
        click button "Displays" of scroll area 1 of window "System Preferences"
        delay 1
        click radio button "Display" of tab group 1 of window "Built-in Retina Display"
        set value of value indicator 1 of slider 1 of group 1 of tab group 1 of window "Built-in Retina Display" to ]] .. value .. [[
      end tell
      delay 1
      quit application "System Preferences"
    end tell
  ]]
  return function()
    hs.osascript.applescript(script)
  end
end

return mod
