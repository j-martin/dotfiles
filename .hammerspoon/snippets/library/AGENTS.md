# Snippet library

Each `<category>.lua` returns a `SnippetGroup` (see `snippets/matcher.lua`).

## File snippets

Long snippets are files in `<category>/`, next to `<category>.lua`, which must exist even with an empty `snippets` list. Any file type works, e.g. `code/hbash.sh`. Files starting with `.` are ignored.

### Header

The header is a `#` comment holding a single-line JSON object with the snippet fields, except `text`:

```sh
# {"trigger":"hbashm","desc":"Common bash (minimal)"}
```

- It is any line of the `#` comment block that starts the file, the first one holding `{...}`. This keeps the file valid, e.g. after a shebang (`#!`) or Python's coding line, which must come first.
- The header line is removed, everything else is the snippet `text`, including the shebang.
- Fields are the ones of `Snippet` in `snippets/matcher.lua`, e.g. `trigger`, `desc`, `aliases`, `prefix`, `suffix`, `skipVocabulary`.
- The group `prefix` and `suffix` of `<category>.lua` apply unless the header overrides them.
- Placeholders such as `{cursor}` or `{clipboard}` work as in Lua snippets, see `mod.render` in `snippets/matcher.lua`.

Example, `code/hpython.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# {"trigger":"hpython","desc":"Python Header"}
```

## TSV snippets

`<category>.tsv`, next to `<category>.lua`, holds one `text<TAB>trigger<TAB>description` per line, parsed by `snippets/tsv_snippets.lua`. Trigger and description can be empty. Backslashes, tabs and newlines in a field are written `\\`, `\t` and `\n`. Its snippets join the `<category>.lua` group, using its name, prefix and suffix. Without a matching `<category>.lua`, the file is its own group, named after the file in title case, e.g. `git-aliases.tsv` is `Git Aliases`.

Private TSV files live in `config.snippetTsvPath`, each its own group named the same way. Hyper + space, shift + s appends the clipboard to `config.snippetTsvNewFile` there.

## JSON snippets

Generated snippets live outside the repository, in `config.snippetJsonPath`: every `*.json` file there is a `SnippetGroup`, e.g. `{"name":"GitHub - Coworkers","snippets":[{"desc":"Jane Doe","text":"jdoe"}]}`, or a plain array of `Snippet`, validated by `snippets/json_snippets.lua`. They load after the library and before the private snippets. Hammerspoon reloads when one changes. `snippets/generator.lua` runs `~/.bin/hammerspoon-snippets-generator` every 12 hours, and on load when the directory has no JSON files. Keep source discovery in Go; Lua only passes the output directory. When `gh` is installed, the generator discovers all organizations with `gh org list` and combines their coworker logins and work emails, deduplicating snippet texts. No GitHub organization setting is needed. When gcloud is installed, it also generates the GCP organizations, billing accounts, a file of projects per organization, and the regions and zones of Canada and the US.
