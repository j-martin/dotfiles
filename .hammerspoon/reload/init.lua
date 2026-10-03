local logger = hs.logger.new('reload', 'debug')

local mod = {}

local function reloadConfig(files)

  hs.fnutils.map(files, function(file)
    logger.df("File changed %s", file)
  end)

  local doReload = false
  for _, file in pairs(files) do
    if file:sub(-4) == ".lua" then
      doReload = true
    end
  end
  if doReload then
    mod.reload()
  end
end

function mod.init()
  -- Keep a reference so the watcher isn't garbage collected
  if mod.watcher then mod.watcher:stop() end
  mod.watcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
end

function mod.reload()
  hs.alert.show('Reloading ...')
  hs.reload()
end

return mod
