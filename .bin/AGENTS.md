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
- I do not want my custom config in `~/.zshrc`.
- There is `~/.private/profile` for config I do not want to be public.
- Before implenting a new function check if we have matching ones. e.g. `_fzf_` etc.
- fuzzy ==> `_fzf` functions

# Hammersppon

- In `~/.hammerspoon`
- There is `~/.private/hammerspoon.json` for config I do not want to be public.

# Emacs Config

- Prioritize custom config in `~/.spacemacs.d/configuration.org` and if not possible `~/.spacemacs.d/.spacemacs`.
- There is `~/.private/configuration.org` for config I do not want to be public.
- Do not modify the config in `~/.emacs.d` beyond removing `.elc` files.
