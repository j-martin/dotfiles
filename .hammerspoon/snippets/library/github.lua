-- Imported from the Alfred 'github' snippets folder, with its keyword prefix and suffix.
---@type SnippetGroup
return {
  name = 'GitHub',
  aliases = { 'gh' },
  prefix = 'gh',
  suffix = ' ',
  snippets = {
    { trigger = 'lgtm', desc = 'LGTM', text = 'Looks good to me 👍', prefix = '', suffix = ' ' },
    {
      trigger = 'prc',
      desc = 'Have you considered',
      text = 'Have you considered using {cursor}?',
    },
    {
      desc = 'Re-review',
      text = 'Can you review the changes?',
    },
    {
      desc = 'That would be great',
      text = '![That would be great](https://memegenerator.net/img/instances/33568413/that-would-be-great.jpg)',
    },
  },
}
