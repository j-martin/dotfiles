# Dotfiles AGENTS.md

Living in this dir since that is `dot-agent` working dir.


# ALWAYS

- Add 🤖 at the end of your responses as the last word. Do not create new lines.
- Never write any secrets or sensitive information in files that may be commited.
- Avoid reference to machine specific local dir/file paths as much as possible.
- Use `mise` tasks (`mise.toml`, `mise run <task>`) for project tasks, never `Taskfile.yml`/`task` or Makefiles. Convert existing `Taskfile.yml` files to `mise.toml` when touching them.
- Iterate on the AGENTS.md file to add new rules and instructions, and update the snippets library accordingly based on the instructions you are given during regular prompting.
- Only add a customization to `~/.setup/setup.sh` if it cannot be committed as a text file or symlink in the home dir, or if it lives outside the home dir.
- Never run `brew install`. Add Homebrew formulae (`"brew:<name>"`) and casks (`"brew-cask:<name>"`) to `[bootstrap.packages]` in `~/.config/mise/conf.d/bootstrap.toml` (or the `.personal`/`.work` variant), then install them with `mise bootstrap packages apply`.
- When refactoring code, renaming, always use `home grep` to check for previous usages.
- Always run `mise run lint` (and fix) and `mise run fmt` after you are done. Never `mise fmt`: it is a mise built-in that only formats `mise.toml` and shadows the `fmt` task.

# Git

- Prefix commit with the part of the system or config. prefix = `<component>, <change-description>`
  - Example of prefixes: `hs`, `emacs`, `sh`, `agent`, `bin`, `setup`.
- If creating or modifying files not tracked and editing the `~/.gitignore`, consider adding a rule for the whole directory if there is no private data in that directory.
- Always check if there is secrets, private, machine specific content before adding or commiting a file change.

# Never

Try to read `~/.private`, if you need information or to write something. Tell me to do it.

# Platform (OS)

- Assume all machines are running macOS.

# Shell

- Starts in `~/.zshrc`, then `~/.config/shell/base` which is the entrypoint into my own custom config, which loads all the functions in `~/.config/shell/functions/` and then the aliases in `~/.config/shell/aliases/` (one file per tool/theme, e.g. `git`, `mise`).
- Never add functions in `~/.config/shell/aliases/` unless they are very simple, non-cryptic, one-liners. Otherwise put them in `~/.config/shell/functions/`.
- I do not want my custom config in `~/.zshrc`.
- There is `~/.private/profile` for config I do not want to be public.
- Before implenting a new function check if we have matching ones. e.g. `_fzf_` etc.
- fuzzy ==> `_fzf` functions
- Scripts file names should start with the component/system they are related to and then what they do.
- Use `kebab-case` in filenames.
- Avoid `.sh`
- Always use the `#!/usr/bin/env bash`
- Shell files (zsh included) must be valid bash: in `~`, `mise run fmt` (`shfmt`) must be ran and `mise run lint` (`shellcheck`) must pass. Vendor code as git submodules: they are excluded from `fmt` and `lint`.

# Hammerspoon

- `hs` == hammerspoon
- In `~/.hammerspoon`
- There is `~/.private/hammerspoon.lua` (a file returning a table, created with the defaults in `utils/private_config.lua` when missing) for config I do not want to be public. When modifying public code, check those files to see if they need to be updated.
- Always use or add luadoc types, this includes local variables, function parameters, and return values. Use `---@class` for tables that are used as objects. Use `---@field` for fields in a table. Use `---@param` for function parameters. Use `---@return` for function return values.
- Global hammerspoon config or settings should go in `config.lua`
- Never call `hs.execute`, `hs.task.new`, `io.popen` or `os.execute` directly. Use `utils/process.lua` (`process.start`, `process.execute`, `process.which`), which provides a PATH with the mise shims first, then `~/bin` and Homebrew. Hammerspoon only has the bare launchd PATH, so tools installed with mise (e.g. `gh`, `go`) are not found otherwise.
- Never hard-code a PATH or executable directories outside `utils/process.lua`.
- Never call `hs.osascript.javascript`, it leaks ~1 MB of JavaScriptCore memory per call inside Hammerspoon. Use `utils/jxa.lua` (`jxa.run`, or `jxa.start` in the background, e.g. in watchers), which runs the script with `/usr/bin/osascript`. Debounce watchers that run scripts.
- `mise run test` must pass.
- `mise run fmt` must be ran.

# Emacs Config

- Prioritize custom config in `~/.spacemacs.d/configuration.org` and if not possible `~/.spacemacs.d/.spacemacs`.
- Never modify files in `~/.emacs.d/` or `~/.spacemacs.d/configuration.el`
- There is `~/.private/configuration.org` for config I do not want to be public.
- Do not modify the config in `~/.emacs.d` beyond removing `.elc` files.
