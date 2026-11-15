-- Imported from the Alfred 'markdown' snippets folder, with its keyword prefix and suffix.
---@type SnippetGroup
return {
  name = 'Markdown',
  aliases = { 'md' },
  prefix = 'm',
  suffix = '  ',
  snippets = {
    {
      trigger = 'diff',
      desc = 'Code - Diff',
      text = [=[
```diff
{clipboard}
```]=],
    },
    {
      trigger = 'l',
      desc = 'Link',
      text = '[{cursor}]({clipboard})',
    },
    {
      trigger = 'm-note',
      desc = 'Markdown Notes',
      text = '> [!NOTE]  \n> ',
    },
    {
      desc = 'Markdown Blocks',
      text = '> [!NOTE]  \n> \n\n> [!TIP]\n> \n\n> [!IMPORTANT]  \n> \n\n> [!WARNING]  \n> \n\n> [!CAUTION]\n> ',
    },
    {
      desc = 'Markdown Expand',
      text = [=[
<details>
  <summary>Expand</summary>

```
{clipboard}
```

</details>]=],
    },
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
