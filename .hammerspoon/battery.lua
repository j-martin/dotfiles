-- strongly inspired from
-- https://github.com/dharmapoudel/hammerspoon-config/blob/master/battery.lua

local battery = require "hs.battery"
local notify = require "hs.notify"
local logger = hs.logger.new('battery', 'debug')

local mod = {}

local state = {
  min = 40,
  remaining = 0
}

local function watchBattery()
  local currentPercentage = battery.percentage()
  local source = battery.powerSource()

  local isLowerThanMin = currentPercentage <= state.min
  local isBattery = source == 'Battery Power'
  local stateHasChanged = state.remaining ~= currentPercentage
  local isMutlipleOf = (currentPercentage % 5 == 0 )

  logger.df("Current percentage: %s", currentPercentage)
  if isLowerThanMin and stateHasChanged and isBattery and isMutlipleOf then
    state.remaining = currentPercentage
    local message = {
      title = battery.title,
      informativeText = 'Battery left: ' .. state.remaining .. "%\nPower Source: " .. source
    }
    notify.new(message):send()
  end
end

function mod.init()
  battery.watcher.new(watchBattery):start()
end

return mod
