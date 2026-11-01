-- Hammerspoon runs on a single thread, so a call blocked by a stuck application blocks it entirely, and cannot be
-- interrupted. This checks, with short accessibility timeouts, that applications answer before switching to them, and
-- that they are frontmost afterwards, so that callers can abort what follows, e.g. sending key strokes.

local logger = hs.logger.new('appGuard', 'info')
local config = require 'config'

---@class AppGuardModule
---@field isResponsive fun(app: hs.application|nil): boolean
---@field ensureResponsive fun(hint: string): boolean
---@field waitUntilFrontmost fun(hint: string, timeout: number|nil): boolean
---@field launchOrFocus fun(name: string): boolean, string|nil
---@field launchOrFocusByBundleID fun(bundleId: string): boolean, string|nil
local mod = {}

---@alias AppGuardFailure 'unresponsive'|'notFound'|'timeout'

---@param message string
local function abort(message)
  logger.w(message)
  hs.alert.show(message)
end

--- Returns whether the application answers accessibility requests within `config.appResponseTimeout`.
--- Applications that are not running are considered responsive.
---@param app hs.application|nil
---@return boolean
function mod.isResponsive(app)
  if not app then
    return true
  end
  ---@type hs.axuielement|nil
  local element = hs.axuielement.applicationElement(app)
  if not element then
    return true
  end
  element:setTimeout(config.appResponseTimeout)
  ---@type any, string|nil
  local role, err = element:attributeValue('AXRole')
  if role == nil and err ~= nil then
    logger.wf('%s did not answer: %s', app:name(), err)
    return false
  end
  return true
end

--- Returns whether the running application matching the name or bundle ID, if any, is responsive.
--- Shows an alert when it is not.
---@param hint string
---@return boolean
function mod.ensureResponsive(hint)
  ---@type hs.application|nil
  local app = hs.application.get(hint)
  if mod.isResponsive(app) then
    return true
  end
  abort(hint .. ' is not responding, aborted')
  return false
end

---@param app hs.application
---@param hint string
---@return boolean
local function matches(app, hint)
  if app:name() == hint or app:bundleID() == hint then
    return true
  end
  ---@type string|nil
  local path = app:path()
  return path ~= nil and (hs.fs.displayName(path):gsub('%.app$', '')) == hint
end

--- Polls, without relying on the run loop which is blocked meanwhile, until the frontmost application matches the
--- name or bundle ID. Returns false once `timeout` seconds have passed.
---@param hint string
---@param timeout number|nil Defaults to `config.appSwitchTimeout`.
---@return boolean
function mod.waitUntilFrontmost(hint, timeout)
  ---@type number
  local deadline = hs.timer.secondsSinceEpoch() + (timeout or config.appSwitchTimeout)
  ---@type hs.axuielement
  local systemWide = hs.axuielement.systemWideElement()
  repeat
    ---@type hs.axuielement|nil
    local focused = systemWide:attributeValue('AXFocusedApplication')
    ---@type hs.application|nil
    local app = focused and focused:asHSApplication()
    if app and matches(app, hint) then
      return true
    end
    hs.timer.usleep(20000)
  until hs.timer.secondsSinceEpoch() > deadline
  return false
end

---@param hint string
---@param launchOrFocus fun(hint: string): boolean
---@return boolean ok
---@return AppGuardFailure|nil failure
local function guardedLaunchOrFocus(hint, launchOrFocus)
  ---@type hs.application|nil
  local app = hs.application.get(hint)
  if not mod.isResponsive(app) then
    abort(hint .. ' is not responding, aborted')
    return false, 'unresponsive'
  end
  if not launchOrFocus(hint) then
    return false, 'notFound'
  end
  if not mod.waitUntilFrontmost(hint, app and config.appSwitchTimeout or config.appLaunchTimeout) then
    abort(hint .. ' did not come to the front, aborted')
    return false, 'timeout'
  end
  return true, nil
end

--- Launches or focuses the application, unless it is not responding, and returns whether it is frontmost in time.
---@param name string
---@return boolean ok
---@return AppGuardFailure|nil failure
function mod.launchOrFocus(name)
  return guardedLaunchOrFocus(name, hs.application.launchOrFocus)
end

--- Launches or focuses the application, unless it is not responding, and returns whether it is frontmost in time.
---@param bundleId string
---@return boolean ok
---@return AppGuardFailure|nil failure
function mod.launchOrFocusByBundleID(bundleId)
  return guardedLaunchOrFocus(bundleId, hs.application.launchOrFocusByBundleID)
end

return mod
