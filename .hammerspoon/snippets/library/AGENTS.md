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

## JSON snippets

Generated snippets live outside the repository, in `config.snippetJsonPath`: every `*.json` file there is a `SnippetGroup`, e.g. `{"name":"GitHub - Coworkers","snippets":[{"desc":"Jane Doe","text":"jdoe"}]}`, or a plain array of `Snippet`, validated by `snippets/json_snippets.lua`. They load after the library and before the private snippets. Hammerspoon reloads when one changes. `snippets/generator.lua` runs `~/.bin/hammerspoon-snippets-generator` every 12 hours, and on load when a file is missing, for the GitHub coworker logins and work emails (`githubOrg` in `snippetsGenerator` of the private config) and, when gcloud is installed, the GCP organizations, billing accounts and a file of projects per organization.
