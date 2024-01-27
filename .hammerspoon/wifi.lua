
local logger = hs.logger.new('wifi', 'debug')

local mod = {}

local previousInterfaceResetTime = 0

function handler(watcher, message, interface, rrsi, rate)
  local currentTime = os.time()
  local homeNetwork = 'Kirbo'
  local minRrsi = -69
  local resetTTLSeconds = 60

  if message == 'linkQualityChange' and network == homeNetwork and rrsi <= minRrsi and currentTime - previousInterfaceResetTime > resetTTLSeconds then
    logger.df('message: %s, interface: %s, rrsi: %s, rate: %s', message, interface, rrsi, rate)
    local network = hs.wifi.currentNetwork(interface)
    logger.df('network: %s', network)

    mod.restartWifi(interface)
    previousInterfaceResetTime = currentTime
  end
end

function mod.restartWifi(interface)
  if not interface then
    interface = 'en0'
  end

  hs.alert.show('Restarting Wi-Fi')
  logger.df('Restarting the interface: %s', interface)
  hs.wifi.setPower(false, interface)
  hs.wifi.setPower(true, interface)
end

function mod.init()
  watcher = hs.wifi.watcher.new(handler)
  watcher:watchingFor({ 'linkChange', 'linkQualityChange' })
  watcher:start()
end

return mod
