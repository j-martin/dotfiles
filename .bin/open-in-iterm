#!/usr/bin/env bash

set -o errexit
set -o pipefail

_open() {
  local directory="$1"

  osascript &>/dev/null <<EOF
tell application "iTerm"
  activate
  tell current window
    create tab with default profile
  end tell
  tell current session of current window
    write text "cd '${directory}'"
  end tell
end tell
EOF
}

_open "${1:-"${PWD}"}"
