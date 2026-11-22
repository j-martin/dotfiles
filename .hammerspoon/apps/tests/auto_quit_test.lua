rawset(_G, 'hs', rawget(_G, 'hs') or { logger = { new = function() end } })
local autoQuit = require 'apps/auto_quit'

local hour = 60 * 60
---@type AutoQuitAppConfig
local warned = { bundleId = 'warned', ttlSeconds = 2 * hour, warnSeconds = hour }

return {
  ['action quits after the ttl without a warning'] = function()
    local config = { bundleId = 'plain', ttlSeconds = 30 }
    assert(autoQuit.action(config, 29, nil) == 'none')
    assert(autoQuit.action(config, 30, nil) == 'quit')
  end,
  ['action warns warnSeconds before the ttl'] = function()
    assert(autoQuit.action(warned, hour - 1, nil) == 'none')
    assert(autoQuit.action(warned, hour, nil) == 'warn')
  end,
  ['action warns instead of quitting when the ttl passed unwarned'] = function()
    assert(autoQuit.action(warned, 5 * hour, nil) == 'warn')
  end,
  ['action quits once the warning has been out for warnSeconds'] = function()
    assert(autoQuit.action(warned, 2 * hour, hour - 1) == 'none')
    assert(autoQuit.action(warned, 2 * hour, hour) == 'quit')
  end,
  ['action waits until asked to warn again, even past the ttl'] = function()
    assert(autoQuit.action(warned, 3 * hour, nil, 1) == 'none')
    assert(autoQuit.action(warned, 3 * hour, nil, 0) == 'warn')
  end,
}
