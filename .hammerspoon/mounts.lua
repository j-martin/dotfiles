local mod = {}

function mod.unmountAll()
  for volume_path, attributes in pairs(hs.volume.allVolumes()) do
    if not attributes.NSURLVolumeIsInternalKey and attributes.NSURLVolumeIsLocalKey
      and not attributes.NSURLVolumeLocalizedFormatDescriptionKey:lower():match('fuse') then
      hs.alert.show('Umounting: ' .. volume_path)
      if not hs.volume.eject(volume_path) then
        hs.alert.show('Failed to umount' .. volume_path)
      end
    end
  end
  hs.alert.show('Unmounting done.')
end

return mod
