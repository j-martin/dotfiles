#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/pushbullet"

_pb_org () {
  local created="$(( 1 + $(echo ${1:-1} | cut -d'.' -f1)))"
  _info "Fetching starting from: $created"
  _pb "pushes?modified_after=$created" | jq -r '.pushes
| reverse[]
| select(has("url"))
| select(.direction == "self")
| ["** TODO [[" + .url + "][" + .title + "]]" , ":PROPERTIES:" , ":ID: " + .iden, ":CREATED: " + (.created | tostring), ":END:", .body]
| join("\n")'
}

_pb_org_last () {
  local file="$1"
  grep ':CREATED:' "$file" | tail -n1 | cut -d ' ' -f2
}

file="$HOME/.org/reading.org"

_pb_org $(_pb_org_last "$file") >> "$file"
_info "Saved to: $file"
