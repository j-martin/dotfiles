#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.private/calendars"

_header () {
  local tag="$1"
  echo "#+TITLE: Calendar"
  echo "#+SETUPFILE: common.org"
  echo "#+FILETAGS: :$tag:"
}

_get_calendar () {
  local tag="$1"
  local urls="${@:2}"
  local output="$HOME/.org/calendar-$tag.org"
  _header "$tag" > "$output"
  for url in $urls; do
    local ical_file="$(mktemp)"
    wget -O "$ical_file" "$url"
    awk -f "$HOME/.bin/ical2org.awk" "$ical_file" >> "$output"
    rm -f "$ical_file"
  done
}

_get_calendar "personal" "$personal_url"
_get_calendar "work" "$work_url" "$work_url2"
