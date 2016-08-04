#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.private/calendars"

_header () {
  local tag="$1"
  echo "#+TITLE: Calendar"
  echo "#+AUTHOR: Jean-Martin Archer"
  echo "#+EMAIL: jm@jmartin.ca"
  echo "#+SETUPFILE: common.org"
  echo "#+FILETAGS: :$tag:"
}

_get_calendar () {
  local url="$1"
  local tag="$2"
  local ical_file="$(mktemp)"
  local output="$HOME/.org/calendar-$tag.org"
  _header "$tag" > "$output"
  wget -O "$ical_file" "$url"
  awk -f "$HOME/.bin/ical2org.awk" "$ical_file" >> "$output"
  rm -f "$ical_file"
}

_get_calendar "$personal_url" "personal"
_get_calendar "$work_url" "work"
