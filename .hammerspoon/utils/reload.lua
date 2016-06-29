local pathwatcher = require "hs.pathwatcher"

local mod = {}

local function reloadConfig(files)
  local doReload = false
  for _,file in pairs(files) do
    if file:sub(-4) == ".lua" then
      doReload = true
    end
  end
  if doReload then
    hs.reload()
  end
end

function mod.init()
  pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
end

return mod
