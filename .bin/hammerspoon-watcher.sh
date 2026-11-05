#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -u
shopt -s inherit_errexit 2> /dev/null || true

IFS=$'\n\t'

_info() {
  echo >&2 "[info] $*"
}

_fatal() {
  local message="$1"
  local code="${2:-255}"
  echo >&2 "[fatal] ${message} Exit code: ${code}"
  exit "${code}"
}

_notify() {
  local message="$1"
  local title="${2:-System}"
  osascript -e "display notification \"${message}\" with title \"${title}\""
}

_main() {
  printf "Running the Hammerspoon Watcher"
  while true; do
    if ! timeout 10 hs -A -q -c '"."' | tr -d '\n'; then
      _info "Restarting Hammerspoon..."
      _notify "Restarting Hammerspoon..."

      pkill -f Hammerspoon || true
      sleep 2
      open /Applications/Hammerspoon.app
      sleep 15
    fi
    sleep 5
  done
}

_main "$@"
