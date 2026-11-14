-- Imported from the Alfred 'typos' snippets folder.
-- Fixed when followed by anything that can end a word in a sentence, e.g. 'suod.' -> 'sudo.'.
---@type SnippetGroup
return {
  name = 'Typos',
  prefix = '',
  suffix = 'sentence',
  snippets = {
    {
      trigger = 'suod',
      desc = 'Sudo',
      text = 'sudo',
      suffix = ' ',
    },
    {
      trigger = 'theses',
      desc = 'Theses',
      text = 'these',
    },
  },
}
