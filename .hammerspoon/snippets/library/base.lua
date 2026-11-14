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
  },
}
