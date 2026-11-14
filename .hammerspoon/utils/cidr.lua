-- IPv4 CIDR matching, e.g. `cidr.contains('192.168.1.0/24', '192.168.1.42')`.
---@class CidrModule
---@field toInteger fun(ip: string): integer|nil
---@field contains fun(cidr: string, ip: string): boolean
---@field anyContains fun(cidrs: string[], ips: string[]): string|nil, string|nil
local mod = {}

--- Returns the IPv4 address as an integer, or nil when it is not a valid address.
---@param ip string
---@return integer|nil
function mod.toInteger(ip)
  ---@type string[]
  local octets = { ip:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$') }
  if #octets ~= 4 then
    return nil
  end
  ---@type integer
  local value = 0
  for _, octet in ipairs(octets) do
    ---@type integer
    local number = math.tointeger(tonumber(octet)) or 256
    if number > 255 then
      return nil
    end
    value = value * 256 + number
  end
  return value
end

--- Whether `ip` is in `cidr`, a bare address being a /32.
---@param cidr string
---@param ip string
---@return boolean
function mod.contains(cidr, ip)
  local network, bits = cidr:match('^([%d%.]+)/(%d+)$')
  network = network or cidr
  ---@type integer|nil
  local prefix = math.tointeger(tonumber(bits or '32'))
  local networkValue = mod.toInteger(network)
  local ipValue = mod.toInteger(ip)
  if not prefix or prefix > 32 or not networkValue or not ipValue then
    return false
  end
  ---@type integer
  local size = 1 << (32 - prefix)
  return networkValue // size == ipValue // size
end

--- Returns the first CIDR and address where the address is in the CIDR, or nil.
---@param cidrs string[]
---@param ips string[]
---@return string|nil cidr
---@return string|nil ip
function mod.anyContains(cidrs, ips)
  for _, cidr in ipairs(cidrs) do
    for _, ip in ipairs(ips) do
      if mod.contains(cidr, ip) then
        return cidr, ip
      end
    end
  end
  return nil, nil
end

return mod
