#!/usr/bin/env bash

set -o errexit
set -o pipefail

_main() {
  brew bundle --global dump --force && sed -i "s/, link: false//"  ~/.Brewfile
  code --list-extensions > "$HOME/.vscode/extensions/list"
}

_main
