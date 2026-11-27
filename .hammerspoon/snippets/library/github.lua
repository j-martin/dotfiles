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
      trigger = 'pr',
      desc = 'Pull request link',
      prompts = {
        { name = 'repo', label = 'Repository, owner/name' },
        { name = 'number', label = 'Pull request number' },
        { name = 'format', label = 'Format', strict = true, choices = { 'Markdown', 'URL' } },
      },
      text = function(values)
        local url = string.format('https://github.com/%s/pull/%s', values.repo, values.number)
        if values.format == 'URL' then
          return url
        end
        return string.format('[%s#%s](%s)', values.repo, values.number, url)
      end,
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
