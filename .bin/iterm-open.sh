#!/usr/bin/env bash

set -o errexit
set -o pipefail

_open() {
  local directory="$1"

  osascript &>/dev/null <<EOF
    tell application "iTerm" to activate
    tell application "System Events" to tell process "iTerm" to keystroke "t" using command down
    tell application "System Events" to tell process "iTerm" to keystroke "cd '${directory}'"
    tell application "System Events" to tell process "iTerm" to key code 52
EOF
}

_open "${1:-"${PWD}"}"
