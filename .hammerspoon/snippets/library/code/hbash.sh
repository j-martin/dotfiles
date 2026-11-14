#!/usr/bin/env bash
# {"trigger":"hbashm","desc":"Common bash (minimal)"}

set -o errexit
set -o pipefail
set -u

IFS=$'\n\t'

readonly BINPATH="$(realpath "$(dirname "$0")")"

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
