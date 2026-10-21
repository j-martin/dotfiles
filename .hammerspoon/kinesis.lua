local logger = hs.logger.new('kinesis', 'debug')

local windows = require 'windows'

local mod = {
  vendorID = 1523,
  productID = 129,
}

local alertId = nil
-- Kept at module level so they are not garbage collected.
local screenWatcher = nil
local refreshTimer = nil

local function isConnected()
  return hs.fnutils.some(hs.usb.attachedDevices() or {}, function(device)
    return device.vendorID == mod.vendorID and device.productID == mod.productID
  end)
end

local function showAlert()
  if alertId then
    return
  end
  alertId = hs.alert.show('⌨️ Kinesis is not connected (USB switch on iPad?)', hs.alert.defaultStyle, hs.screen.mainScreen(), true)
end

local function closeAlert()
  if alertId then
    hs.alert.closeSpecific(alertId)
    alertId = nil
  end
end

-- Shows a persistent alert while an ultrawide screen is connected but the Kinesis keyboard is not.
function mod.refresh()
  local shouldAlert = windows.hasUltraWideScreen() and not isConnected()
  logger.df('refresh: shouldAlert=%s', shouldAlert)
  if shouldAlert then
    showAlert()
  else
    closeAlert()
  end
end

-- Hides the alert right away since the added event already confirms the keyboard is back.
function mod.onConnected()
  if refreshTimer then
    refreshTimer:stop()
    refreshTimer = nil
  end
  closeAlert()
end

-- Refreshes after a short delay since devices and screens may not be settled when events fire.
function mod.refreshLater()
  if refreshTimer then
    refreshTimer:stop()
  end
  refreshTimer = hs.timer.doAfter(2, mod.refresh)
end

-- Starts watching screen changes and checks the initial state.
function mod.init()
  screenWatcher = hs.screen.watcher.new(mod.refreshLater)
  screenWatcher:start()
  mod.refresh()
end

return mod
