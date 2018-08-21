local alert = require "hs.alert"
local volume = require "hs.fs.volume"
local logger = hs.logger.new('mounts', 'debug')

local mod = {}

function mod.unmountAll()
  logger.d('Unmounting volumes')
  for volume_path, attributes in pairs(volume.allVolumes()) do
    if not attributes.NSURLVolumeIsInternalKey and attributes.NSURLVolumeIsLocalKey and not attributes.NSURLVolumeLocalizedFormatDescriptionKey:lower():match('fuse') then
      alert('Umounting: ' .. volume_path)
      if not volume.eject(volume_path) then
        alert('Failed to umount' .. volume_path)
      end
    end
  end
end

return mod
