#!/usr/bin/env bash

set -o errexit
set -o pipefail
IFS=$'\n'

source "$HOME/.functions/base"
source "$HOME/.functions/pushbullet"

org_dir="$HOME/.org"
ref_file="$org_dir/references.org"

_pb_fetch () {
  local created="$1"
  _info "Fetching starting from: $created"
  _pb "pushes?modified_after=$created" \
    | jq -c '.pushes
      | reverse[]
      | select(has("url"))
      | select(.direction == "self")'
}

_pb_format_entry () {
  local entry="$1"

  local title="$(echo "$entry" | jq -r ".title // .url")"
  local url="$(echo "$entry" | jq -r ".url")"
  local ref_path="references/$(_pb_create_filename "$title").org"

  printf "\n** [[file:${ref_path}][${title}]]\n"
  echo "$entry" \
    | jq -r '[
        ":PROPERTIES:",
        ":ID: " + .iden,
        ":CREATED: " + (.created | tostring),
        ":MODIFIED: " + (.modified | tostring),
        ":URL: [[\(.url)][url]]",
        ":END:",
        .body
      ] | join("\n")'

  _pb_convert_page "$url" > "${org_dir}/${ref_path}"
}

_pb_create_filename () {
  echo "$1" | sed -e 's/[^A-Za-z0-9._-]/_/g' | tr '[:upper:]' '[:lower:]'
}

_pb_org () {
  local created="$(( 1 + $(echo ${1:-1} | cut -d'.' -f1)))"
  for entry in $(_pb_fetch "$created"); do
    _pb_format_entry "$entry"
  done
}

_pb_org_last () {
  local ref_file="$1"
  grep ':MODIFIED:' "$ref_file" | tail -n1 | cut -d ' ' -f2
}

_pb_convert_page () {
  local url="$1"
  echo "#+STARTUP: showeverything"
  echo "#+CREATED_AT: $(date -u +%Y-%m-%dT%H:%M:%S%z)"
  echo "#+URL: [[$url][url]]"
  python -m readability.readability -u "$url" \
    | pandoc --columns 100 -f html -t org \
    | sed 's/^Title:/#+TITLE: /g; /#+BEGIN\_HTML/,/#+END\_HTML/d'
}

_pb_org "$(_pb_org_last "$ref_file")" >> "$ref_file"
_info "Saved to: $ref_file"
