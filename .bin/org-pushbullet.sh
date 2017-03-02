#!/usr/bin/env bash

set -o errexit
set -o pipefail
IFS=$'\n'

source "$HOME/.functions/base"
source "$HOME/.private/.profile"

ORG_DIR="$HOME/.org"
REF_FILE="${ORG_DIR}/references.org"

_pb () {
  local endpoint="$1"
  curl --fail --silent --header "Access-Token: ${PB_TOKEN}" \
       "https://api.pushbullet.com/v2/$endpoint"
}

_pb_fetch () {
  local created="$1"
  _info "Fetching starting from: $created"
  _pb "pushes?modified_after=$created" \
    | jq -c '.pushes
      | reverse[]
      | select(has("url"))
      | select(.direction == "self")'
  _info "Fetching done."
}

_pb_format_entry () {
  local entry="$1"

  local title="$(echo "${entry}" | jq -r ".title // .url")"
  local url="$(echo "${entry}" | jq -r ".url")"
  local ref_path="references/$(_pb_create_filename "${title}").org"
  local ref_raw_path="raw/$(_pb_create_filename "${title}").org"

  _info "Processing: '${title}'"
  echo ''
  echo "** [[file:${ref_path}][${title}]]" >> "$REF_FILE"
  echo ":PROPERTIES:" >> "$REF_FILE"
  # echo ":RAW: [[file:${ref_raw_path}][raw]]" >> "$REF_FILE"
  echo "$entry" \
    | jq -r '[
        ":URL: [[\(.url)][url]]",
        ":ID: " + .iden,
        ":CREATED: \(.created | tostring)",
        ":MODIFIED: \(.modified | tostring)",
        ":END:",
        .body
      ] | join("\n")' >> "$REF_FILE"

  _info "Converting..."
  _pb_store_page "$url" > "${ORG_DIR}/${ref_path}"
  # _pb_store_page_raw "$url" > "${ORG_DIR}/${ref_raw_path}"
  _info "Stored '${ORG_DIR}/${ref_path}'"
}

_pb_create_filename () {
  echo "$1" | sed -e 's/[^A-Za-z0-9._-]/_/g' | tr '[:upper:]' '[:lower:]'
}

_pb_org () {
  local created="$(( 100 + $(echo ${1:-1} | cut -d'.' -f1)))"
  for entry in $(_pb_fetch "${created}"); do
    _pb_format_entry "${entry}"
  done
}

_pb_org_last () {
  grep ':MODIFIED:' "${REF_FILE}" | tail -n1 | cut -d ' ' -f2
}

_pb_convert_page () {
  pandoc --columns 100 -f html -t org \
    | sed 's/^Title:/#+TITLE: /g; /\[\[\]\[\]\]/d; s/\]\[\]\]/\]\[url\]\] /g; /:PROPERTIES:/,/:END:/d; /#+BEGIN\_HTML/,/#+END\_HTML/d' \
    | sed '/^$/N;/^\n$/D'
}

_pb_page_header () {
  local url="$1"
  echo "#+STARTUP: showeverything"
  echo "#+CREATED_AT: $(date -u +%Y-%m-%dT%H:%M:%S%z)"
  echo "#+URL: ${url}"
}

_pb_store_page () {
  local url="$1"
  _pb_page_header "${url}"
  pipenv run python -m readability.readability -u "${url}" | _pb_convert_page
}

_pb_store_page_raw () {
  local url="$1"
  _pb_page_header "${url}"
  curl --fail --silent "${url}" | _pb_convert_page
}

_pb_org "$(_pb_org_last)"
_info "Saved to '${REF_FILE}'"
