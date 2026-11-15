-- Imported from the Alfred 'base' snippets folder, with its keyword prefix and suffix.
---@type SnippetGroup
return {
  name = 'Base',
  prefix = '',
  suffix = '  ',
  snippets = {
    {
      trigger = 'now',
      desc = 'Current date',
      text = '{date:short}',
    },
    {
      trigger = 'dt',
      desc = 'Datetime',
      text = '{date:short} {time:short}',
    },
    {
      trigger = 'time',
      desc = 'Time',
      text = '{time:short}',
    },
    {
      trigger = 'np!',
      desc = 'You are welcome!',
      text = 'You are welcome!',
    },
    {
      trigger = 'np',
      desc = 'You are welcome',
      text = 'You are welcome.',
    },
    {
      trigger = 'cjm',
      desc = 'Cheers',
      text = 'Cheers,\n\nJM',
    },
    {
      trigger = 'tjm',
      desc = 'Thanks',
      text = 'Thanks,\n\nJean-Martin',
    },
    {
      trigger = 'jm',
      desc = 'Name',
      text = 'Jean-Martin Archer',
    },
    {
      desc = 'No Hi Hello',
      text = 'This is an automated message: starting the discussion with "hi", "hello", etc., and other politeness is great and welcome. :slightly_smiling_face: That being said, it would be preferable to include it in the message to avoid too many distractions or having your recipient hold their breath to know why you are reaching out :slightly_smiling_face: . See https://nohello.net/en/ for more information.',
    },
    {
      desc = 'No Screenshots of Text',
      text = 'nit: please no screenshot of logs. It makes it harder to help (you can\'t copy and paste text without OCR) and forces people to click on the screenshot to read it, then deal with the various text sizes and colors. Sometimes, it\'s very "bad" and unreadable. :upside_down_face: ',
    },
    {
      desc = 'Reschedule',
      text = "If the time doesn't work, feel free to reschedule this event. 🙂",
    },
    {
      desc = 'Mark this as done',
      text = "I'll mark this as done for now. :slightly_smiling_face: ",
    },
    {
      desc = 'Support - Closing Ticket',
      text = "\nI'll mark this as resolved, but please feel free to continue the discussion here. 🙂",
    },
  },
}
