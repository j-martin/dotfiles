-- strongly inspired from
-- https://github.com/dharmapoudel/hammerspoon-config/blob/master/battery.lua
local logger = hs.logger.new('hs.battery', 'debug')

local mod = {}

local state = {min = 40, remaining = 0}

local function watchBattery()
  local currentPercentage = hs.battery.percentage()
  local source = hs.battery.powerSource()

  local isLowerThanMin = currentPercentage <= state.min
  local stateHasChanged = state.remaining ~= currentPercentage
  local isDischarging = hs.battery.powerSource() == 'Battery Power' or hs.battery.amperage() < 0
  local isMutlipleOf = (currentPercentage % 5 == 0)

  logger.df("Current percentage: %s", currentPercentage)
  if isLowerThanMin and stateHasChanged and isDischarging and isMutlipleOf then
    state.remaining = currentPercentage
    local message = {
      title = hs.battery.title,
      informativeText = 'Battery left: ' .. state.remaining .. "%\nPower Source: " .. source,
    }
    hs.notify.new(message):send()
  end
end

function mod.init()
  hs.battery.watcher.new(watchBattery):start()
end

return mod
