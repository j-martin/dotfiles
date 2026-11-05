# Dotfiles AGENTS.md

Living in this dir since that is `dot-agent` working dir.


# ALWAYS

- Add 🤖 at the end of your responses as the last word. Do not create new lines.
- Never write any secrets or sensitive informations in files that may be commited.
- Avoid refererence to machine speficic local dir/file paths as much as possible.

# Never

Try to read `~/.private`, if you need information or to write soemthing. Tell me
to do it.

# Platform

- Assume all machines are running macOS.

# Shell

- Starts in `~/.zshrc`, then `~/.base` which is the entrypoint into my own custom config, which loads `~/.aliases` and then all the functions in `~/.functions`.
- Never add functions in `~/.aliases` unless they are very simple, non-cryptic, one-liners. Otherwise put them in `~/.functions`.
- I do not want my custom config in `~/.zshrc`.
- There is `~/.private/profile` for config I do not want to be public.
- Before implenting a new function check if we have matching ones. e.g. `_fzf_` etc.
- fuzzy ==> `_fzf` functions
- Scripts file names should start with the component/system they are related to and then what they do.
- Use `kebab-case` in filenames.
- Avoid `.sh`
- Always use the `#!/usr/bin/env bash`

# Hammerspoon

- `hs` == hammerspoon
- In `~/.hammerspoon`
- There is `~/.private/hammerspoon.json` for config I do not want to be public.
- Always use or add luadoc types, this includes local variables, function parameters, and return values. Use `---@class` for tables that are used as objects. Use `---@field` for fields in a table. Use `---@param` for function parameters. Use `---@return` for function return values.
- Global hammerspoon config or settings chould go in `config.lua`

# Emacs Config

- Prioritize custom config in `~/.spacemacs.d/configuration.org` and if not possible `~/.spacemacs.d/.spacemacs`.
- Never modify files in `~/.emacs.d/` or `~/.spacemacs.d/configuration.el`
- There is `~/.private/configuration.org` for config I do not want to be public.
- Do not modify the config in `~/.emacs.d` beyond removing `.elc` files.
