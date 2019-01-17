local alert = require "hs.alert"
local pathwatcher = require "hs.pathwatcher"
local logger = hs.logger.new('reload', 'debug')
local fnutils = require 'hs.fnutils'

local mod = {}

local function reloadConfig(files)

  fnutils.map(files, function(file) logger.df("File changed %s", file) end)

  local doReload = false
  for _,file in pairs(files) do
    if file:sub(-4) == ".lua" then
      doReload = true
    end
  end
  if doReload then
    mod.reload()
  end
end

function mod.init()
  pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
end

function mod.reload()
  alert.show('Reloading ...')
  hs.reload()
end

return mod
