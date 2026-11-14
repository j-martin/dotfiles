-- Imported from the Alfred 'markdown' snippets folder, with its keyword prefix and suffix.
---@type SnippetGroup
return {
  name = 'Markdown',
  aliases = { 'md' },
  prefix = 'm',
  suffix = '  ',
  snippets = {
    {
      trigger = '1',
      desc = 'Code - Single',
      text = '`{clipboard}`',
    },
    {
      trigger = '3',
      desc = 'Code - Triple',
      text = [=[
```
{clipboard}
```]=],
    },
    {
      desc = 'LGTM - I have no idea what I am doing',
      text = [=[
LGTM
![](https://i.kym-cdn.com/entries/icons/original/000/008/342/ihave.jpg)]=],
    },
  },
}
