local cidr = require 'utils/cidr'

---@type table<string, fun()>
local cases = {}

function cases.containsMatchesPrefix()
  assert(cidr.contains('192.168.1.0/24', '192.168.1.42'))
  assert(not cidr.contains('192.168.1.0/24', '192.168.2.42'))
  assert(cidr.contains('10.0.0.0/8', '10.255.1.1'))
  assert(cidr.contains('172.16.0.0/12', '172.31.255.255'))
  assert(not cidr.contains('172.16.0.0/12', '172.32.0.0'))
end

function cases.containsEdges()
  assert(cidr.contains('0.0.0.0/0', '8.8.8.8'))
  assert(cidr.contains('192.168.1.5', '192.168.1.5'))
  assert(not cidr.contains('192.168.1.5', '192.168.1.6'))
  assert(cidr.contains('192.168.1.5/32', '192.168.1.5'))
end

function cases.containsRejectsInvalid()
  assert(not cidr.contains('192.168.1.0/33', '192.168.1.1'))
  assert(not cidr.contains('192.168.1.0/24', '192.168.1.256'))
  assert(not cidr.contains('192.168.1.0/24', 'fe80::1'))
  assert(not cidr.contains('nope', '192.168.1.1'))
end

function cases.anyContainsReturnsMatch()
  local matched, ip = cidr.anyContains({ '10.0.0.0/8', '192.168.1.0/24' }, { '172.17.0.1', '192.168.1.9' })
  assert(matched == '192.168.1.0/24', tostring(matched))
  assert(ip == '192.168.1.9', tostring(ip))
  assert(cidr.anyContains({ '10.0.0.0/8' }, { '192.168.1.9' }) == nil)
end

return cases
