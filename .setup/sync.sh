#!/usr/bin/env bash

set -o errexit
set -o pipefail

_main() {
  # Lists packages missing from the curated ~/.Brewfile; a dump would re-add mise-managed tools.
  brew bundle --global cleanup || true
  code --list-extensions > "$HOME/.vscode/extensions/list"
}

_main
