rawset(_G, 'hs', rawget(_G, 'hs') or { logger = { new = function() end } })
local googleMeet = require 'apps/google_meet'

return {
  ['isMeetUrl accepts a meeting URL'] = function()
    assert(googleMeet.isMeetUrl('https://meet.google.com/meet/tnx-nyob-sck?authuser=0&pli=1'))
  end,
  ['isMeetUrl ignores the host case'] = function()
    assert(googleMeet.isMeetUrl('https://Meet.Google.com/tnx-nyob-sck'))
  end,
  ['isMeetUrl rejects other Google hosts'] = function()
    assert(not googleMeet.isMeetUrl('https://drive.google.com/drive/u/0/my-drive'))
  end,
  ['isMeetUrl rejects a Meet URL in the path of another host'] = function()
    assert(not googleMeet.isMeetUrl('https://example.com/?next=https://meet.google.com/abc'))
  end,
  ['isMeetUrl rejects non http URLs'] = function()
    assert(not googleMeet.isMeetUrl('chrome://newtab/'))
  end,
}
