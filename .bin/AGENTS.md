# ALWAYS
Add 🤖 at the end of your responses as the last word. Do not create new lines.

# Shell

- Always use full length arguments for shell commands, e.g. `--help` instead of `-h`, `--version` instead of `-v`, etc.
- Starts in `~/.zshrc`, then `~/.base` which is the entrypoint into my own custom config, which loads `~/.aliases` and then all the functions in `~/.functions`.
- I do not want my custom config in `~/.zshrc`.
- There is `~/.private/profile` for config I do not want to be public.
- `shellcheck` must pass
- "Like" python, functions should start with `_` and private functions should start with `__`

# Hammersppon

- In `~/.hammerspoon`
- There is `~/.private/hammerspoon.json` for config I do not want to be public.

# Emacs Config

- Prioritize custom config in `~/.spacemacs.d/configuration.org` and if not possible `~/.spacemacs.d/.spacemacs`.
- There is `~/.private/configuration.org` for config I do not want to be public.
- Do not modify the config in `~/.emacs.d` beyond removing `.elc` files.
