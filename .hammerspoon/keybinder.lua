local logger = hs.logger.new('keybinder', 'info')
local windows = require 'windows'
local chrome = require 'chrome'

local hyper = {'cmd', 'alt', 'ctrl'}
local hyperShift = {'cmd', 'alt', 'ctrl', 'shift'}
local globalBindings = '*'

hs.hotkey.alertDuration = 2.5

local mod = {cmd = {'cmd'}, hyper = hyper, globalBindings = globalBindings}

function enableBindings(bindings, window)
  for _, binding in pairs(bindings) do
    binding.hotkey:enable()
  end
end

function disableBindings(bindings)
  for _, binding in pairs(bindings) do
    binding.hotkey:disable()
  end
end

local function buildBindFunction(binding)
  if binding.pos then
    return windows.setPosition(binding.pos, binding.posUltraWide, binding.reversable)
  elseif binding.name then
    return windows.launchOrCycleFocus(binding.name)
  elseif binding.tab then
    return chrome.activateTab(binding.tab)
  elseif binding.fn then
    return binding.fn
  end
end

local function bind(binding)
  modifiers = binding.modifiers
  if modifiers == nil then
    modifiers = hyper
    if binding.shift then
      modifiers = hyperShift
    end
  end
  local fn = buildBindFunction(binding)
  if fn == nil then
    logger.ef('Missing binding function for: %s', hs.inspect(binding))
  end
  binding.hotkey = hs.hotkey.new(modifiers, binding.key, fn, message)
  return binding
end

function initWatcher(appBindingMap)
  local activated = {}
  activated[hs.application.watcher.activated] = true
  activated[hs.application.watcher.launched] = true
  activated[hs.application.watcher.launching] = true
  activated[hs.application.watcher.unhidden] = true

  return hs.application.watcher.new(function(appName, event, appObj)
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

function mod.init(appBindingList)
  local appBindingMap = {}
  for _, app in ipairs(appBindingList) do
    appBindingMap[app.name] = hs.fnutils.imap(app.bindings, bind)
  end
  enableBindings(appBindingMap[globalBindings])
  initWatcher(appBindingMap):start()
end

return mod
