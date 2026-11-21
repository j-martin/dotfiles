#!/usr/bin/env bash
# {"trigger":"hbashm","aliases":["hbash"],"desc":"Common bash (minimal)"}

set -o errexit
set -o pipefail
set -u

IFS=$'\n\t'

BINPATH="$(realpath "$(dirname "$0")")"
readonly BINPATH

_gnu() {
  if [[ "$(uname)" == "Darwin" ]]; then
    "g${1}" "${@:2}"
  else
    "$@"
  fi
}

_info() {
  echo >&2 "[info] $*"
}

_fatal() {
  local message="$1"
  local code="${2:-255}"
  echo >&2 "[fatal] ${message} Exit code: ${code}"
  exit "${code}"
}

_main() {
  echo Write your script here. Use _info and _fatal for logging.
}

_main "$@"
