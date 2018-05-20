#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.private/calendars"

_header () {
  local tag="${1}"
  echo "#+TITLE: Calendar"
  echo "#+SETUPFILE: common.org"
  echo "#+FILETAGS: :${tag}:"
}

_get_calendar () {
  local tag="${1}"
  local urls="${@:2}"
  local output="${HOME}/.org/calendar-${tag}.org"
  _header "${tag}" > "${output}"
  for url in $urls; do
    curl "${url}" | awk -f "${HOME}/.bin/ical2org.awk" >> "${output}"
  done
}

_get_calendar "personal" "${personal_calendar}"
_get_calendar "work" "${work_calendar}"
