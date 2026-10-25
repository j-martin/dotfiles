local logger = hs.logger.new('keybinder', 'info')
local windows = require 'windows'
local apps = require 'apps'
local cheatsheet = require 'keybinder/cheatsheet'

---@class KeybindingDefinition
---@field key string
---@field fn function|nil
---@field name string|nil
---@field desc string|nil
---@field modifiers string[]|nil
---@field shift boolean|nil
---@field pos table[]|nil
---@field posUltraWide table[]|nil
---@field reversable boolean|nil
---@field remap table|nil
---@field hotkey hs.hotkey|nil
---@field tab string|nil

---@class AppBinding
---@field name string
---@field bindings KeybindingDefinition[]

---@class KeybinderModule
---@field cmd string[]
---@field hyper string[]
---@field globalBindings string
---@field showBindings fun()
---@field init fun(appBindingList: AppBinding[])
local hyper = { 'cmd', 'alt', 'ctrl' }
local hyperShift = { 'cmd', 'alt', 'ctrl', 'shift' }
local globalBindings = '*'

local mod = { cmd = { 'cmd' }, hyper = hyper, globalBindings = globalBindings }

---@param bindings KeybindingDefinition[]
---@param window hs.window|nil
local function enableBindings(bindings, window)
  for _, binding in pairs(bindings) do
    binding.hotkey:enable()
  end
end

---@param bindings KeybindingDefinition[]
local function disableBindings(bindings)
  for _, binding in pairs(bindings) do
    binding.hotkey:disable()
  end
end

---@param binding KeybindingDefinition
---@return function|nil
local function buildBindFunction(binding)
  if binding.pos then
    return windows.setPosition(binding.pos, binding.posUltraWide, binding.reversable)
  elseif binding.name then
    return windows.launchOrCycleFocus(binding.name)
  elseif binding.tab then
    return apps.brave.activateTab(binding.tab)
  elseif binding.remap then
    return function()
      hs.eventtap.keyStroke(binding.remap.modifiers or {}, binding.remap.key)
    end
  elseif binding.fn then
    return binding.fn
  end
end

---@param binding KeybindingDefinition
---@return KeybindingDefinition
local function bind(binding)
  local modifiers = binding.modifiers
  if modifiers == nil then
    modifiers = hyper
    if binding.shift then
      modifiers = hyperShift
    end
  end
  if binding.remap and binding.desc == nil then
    binding.desc = 'Remap to ' .. cheatsheet.modifiersString(binding.remap.modifiers) .. binding.remap.key:upper()
  end
  local fn = buildBindFunction(binding)
  if fn == nil then
    logger.ef('Missing binding function for: %s', hs.inspect(binding))
  end
  binding.hotkey = hs.hotkey.new(modifiers, binding.key, fn)
  return binding
end

---@param appBindingMap table<string, KeybindingDefinition[]>
local function subscribeToApplicationEvents(appBindingMap)
  local activated = {}
  activated[hs.application.watcher.activated] = true
  activated[hs.application.watcher.launched] = true
  activated[hs.application.watcher.launching] = true
  activated[hs.application.watcher.unhidden] = true

  apps.subscribe(function(appName, event)
    local bindings = appBindingMap[appName]
    if bindings == nil then
      return
    end

    if activated[event] ~= nil then
      logger.df('Enabling for %s', appName)
      enableBindings(bindings, hs.window.focusedWindow())
      return
    end

    logger.df('Disabling for %s', appName)
    disableBindings(bindings)
  end)
end

-- Register a cheatsheet section per application; bindings without explicit
-- modifiers use hyper, so the section title shows it.
---@param appBindingList AppBinding[]
local function registerCheatsheet(appBindingList)
  local hyperTitle = ' (' .. cheatsheet.modifiersString(hyper) .. ')'
  for _, app in ipairs(appBindingList) do
    local title = app.name == globalBindings and 'Hyper' .. hyperTitle or app.name
    cheatsheet.register(title, app.bindings)
  end
end

-- Show every binding registered so far (hyper bindings, app bindings, modes, ...).
function mod.showBindings()
  cheatsheet.show()
end

---@param appBindingList AppBinding[]
function mod.init(appBindingList)
  local appBindingMap = {}
  for _, app in ipairs(appBindingList) do
    appBindingMap[app.name] = hs.fnutils.imap(app.bindings, bind)
  end
  registerCheatsheet(appBindingList)
  enableBindings(appBindingMap[globalBindings])
  subscribeToApplicationEvents(appBindingMap)

  local frontmost = hs.application.frontmostApplication()
  local frontmostBindings = frontmost and appBindingMap[frontmost:name()]
  if frontmostBindings and frontmost:name() ~= globalBindings then
    enableBindings(frontmostBindings)
  end
end

return mod
