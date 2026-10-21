#!/usr/bin/env bash

set -o errexit
set -o pipefail

_main() {
  "$HOME/.local/bin/mise" bootstrap packages import --global --dry-run
  code --list-extensions > "$HOME/.vscode/extensions/list"
}

_main
