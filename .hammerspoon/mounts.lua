local alert = require "hs.alert"
local volume = require "hs.fs.volume"
local logger = hs.logger.new('mounts', 'debug')

local mod = {}

function mod.unmountAll()
  for volume_path, attributes in pairs(volume.allVolumes()) do
    if not attributes.NSURLVolumeIsInternalKey and attributes.NSURLVolumeIsLocalKey and not attributes.NSURLVolumeLocalizedFormatDescriptionKey:lower():match('fuse') then
      alert.show('Umounting: ' .. volume_path)
      if not volume.eject(volume_path) then
        alert.show('Failed to umount' .. volume_path)
      end
    end
  end
  alert.show('Unmounting done.')
end

return mod
