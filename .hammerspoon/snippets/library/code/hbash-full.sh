#!/usr/bin/env bash
# {"desc":"Common bash (full, with argument parsing)"}

set -o errexit
set -o pipefail
set -o errtrace
set -u
shopt -s inherit_errexit 2>/dev/null || true

IFS=$'\n\t'

readonly BINPATH="$(realpath "$(dirname "$0")")"

_debug() {
  _silent echo "[debug] $*"
}

_info() {
  echo >&2 "[info] $*"
}

_warn() {
  echo >&2 "[warn] $*"
}

_error() {
  echo >&2 "[error] $*"
}

_fatal() {
  local message="$1"
  local code="${2:-255}"
  echo >&2 "[fatal] ${message} Exit code: ${code}"
  exit "${code}"
}

_gnu() {
  if [[ "$(uname)" == "Darwin" ]]; then
    "g${1}" "${@:2}"
  else
    "$@"
  fi
}

_has_no_invalid_args() {
  if [[ "${#invalid_args[@]}" != 0 ]]; then
    _fatal "Invalid argument(s): '${invalid_args[*]}'." 2
  fi
}

_usage() {
  cat >&2 << EOF
USAGE: $0 [OPTIONS] COMMANDS...

Wrapper around our different services/application. It's able to start everything

COMMANDS:
  s, start          Recreates the db (if not present) and starts the base

UPLOAD ARGUMENTS:
  -v, --vendor        Passes the vendor to each commands

EOF
}

_main() {
  local command=()
  local invalid_args=()
  if [[ "$#" == 0 ]]; then
    _usage
    _fatal "Pass a valid command." 3
  fi

  local vendor='something'

  while [[ "$#" -gt 0 ]]; do
    local key="$1"
    shift
    case "${key}" in
      -h | --help | h | help)
        _usage
        exit 0
        ;;
      --vendor)
        vendor="$1"
        shift
        ;;
      -*)
        invalid_args+=("${key}")
        ;;
      *)
        command+=("${key}")
        ;;
    esac
  done

  _has_no_invalid_args "${invalid_args[@]}"

  for command in "${command[@]}"; do
    case "${command}" in
      list-vendors)
        echo "${vendor}"
        ;;
      *)
        invalid_args+=("${key}")
        ;;
    esac
  done

  _has_no_invalid_args "${invalid_args[@]}"
}

_main "$@"
