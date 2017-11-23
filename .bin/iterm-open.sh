#!/usr/bin/env bash

set -o errexit
set -o pipefail

_open() {
  local directory="$1"

  osascript &>/dev/null <<EOF
set the clipboard to "cd '${directory}'"
tell application "iTerm2" to activate
tell application "System Events" to tell process "iTerm" to keystroke "t" using {command down}
tell application "System Events" to tell process "iTerm" to keystroke "v" using {command down}
tell application "System Events" to tell process "iTerm" to key code 52
EOF
}

_open "${1:-"${PWD}"}"
