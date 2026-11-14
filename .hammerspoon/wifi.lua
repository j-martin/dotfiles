-- Turns Tailscale on or off when joining a Wi-Fi network listed in the private config `networks`,
-- and only when the Wi-Fi interface also has an address in one of that network's CIDRs, e.g.
--   networks = { { ssid = 'Office', cidrs = { '192.168.1.0/24' }, tailscale = false } }
-- Runs `tailscale up` on any other network, including for no Wi-Fi network.
-- Reading the SSID requires Location Services to be enabled for Hammerspoon.
local logger = hs.logger.new('wifi', 'info')

local cidr = require 'utils/cidr'
local privateConfig = require 'utils/private_config'
local process = require 'utils/process'

---@class WifiNetwork
---@field ssid string
---@field cidrs string[]
---@field tailscale boolean Whether Tailscale is up on this network.

---@class WifiModule
---@field settleDelay number Seconds waited after a change, as the address is assigned after joining the network.
---@field init fun()
---@field check fun()
local mod = {
  settleDelay = 3,
}

-- Kept at module level so they are not garbage collected.
---@type hs.wifi.watcher|nil
local wifiWatcher = nil
---@type hs.network.configuration|nil
local ipWatcher = nil
---@type hs.timer.delayed|nil
local delayedCheck = nil
-- Key of the last action, `down <ssid> <ip>` or `up`, kept across reloads so each runs once per change.
local stateKey = 'wifi.tailscaleState'

---@param interface string
---@return string[]
local function ipv4Addresses(interface)
  local details = hs.network.interfaceDetails(interface) or {}
  local ipv4 = details.IPv4 or {}
  return ipv4.Addresses or {}
end

---@param state string
---@param command string
---@param message string
local function apply(state, command, message)
  if hs.settings.get(stateKey) == state then
    return
  end
  hs.settings.set(stateKey, state)
  logger.f('%s, running tailscale %s', message, command)
  hs.alert.show('Tailscale ' .. command .. ': ' .. message)
  process.start('tailscale', { command }, nil, 10)
end

--- Checks the current network, applying the `tailscale` setting of the matching network, `tailscale up` otherwise.
function mod.check()
  ---@type WifiNetwork[]
  local networks = privateConfig.get('networks') or {}
  if #networks == 0 then
    return
  end
  if hs.location.authorizationStatus() ~= 'authorized' then
    logger.w('Location Services are disabled for Hammerspoon, the SSID is unknown')
    return
  end
  local interface = hs.wifi.interfaces()[1]
  local ssid = hs.wifi.currentNetwork(interface)
  if not ssid then
    apply('up', 'up', 'no Wi-Fi network')
    return
  end
  local addresses = ipv4Addresses(interface)
  logger.df('On %s with %s', ssid, hs.inspect(addresses))

  for _, network in ipairs(networks) do
    if network.ssid == ssid then
      local matchedCidr, ip = cidr.anyContains(network.cidrs or {}, addresses)
      if matchedCidr then
        local message = string.format('on %s with %s in %s', ssid, ip, matchedCidr)
        if network.tailscale then
          apply('up', 'up', message)
        else
          apply('down ' .. ssid .. ' ' .. ip, 'down', message)
        end
        return
      end
    end
  end
  apply('up', 'up', 'on ' .. ssid)
end

function mod.init()
  -- Prompts for Location Services, without which the SSID is nil.
  if hs.location.authorizationStatus() == 'undefined' then
    hs.location.start()
    hs.location.stop()
  end

  delayedCheck = hs.timer.delayed.new(mod.settleDelay, mod.check)
  local function scheduleCheck()
    delayedCheck:start()
  end

  wifiWatcher = hs.wifi.watcher.new(scheduleCheck):watchingFor({ 'SSIDChange' }):start()

  local interface = hs.wifi.interfaces()[1]
  if interface then
    ipWatcher = hs.network.configuration
      .open()
      :setCallback(scheduleCheck)
      :monitorKeys('State:/Network/Interface/' .. interface .. '/IPv4')
      :start()
  end

  scheduleCheck()
end

return mod
