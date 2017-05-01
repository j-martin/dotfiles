#!/usr/bin/env bash

set -o errexit
set -o pipefail
IFS=$'\n'

source "$HOME/.functions/base"
source "$HOME/.private/.profile"

ORG_DIR="$HOME/.org"
REF_FILE="${ORG_DIR}/references.org"

_pb() {
  local endpoint="$1"
  curl --fail --silent --header "Access-Token: ${PB_TOKEN}" \
    "https://api.pushbullet.com/v2/$endpoint"
}

_pb_fetch() {
  local modified="$1"
  local cursor="$2"

  _info "Fetching starting from: $modified $cursor"
  local url="pushes?modified_after=$modified&cursor=${cursor}"

  local data
  data="$(_pb "${url}")"
  cursor="$(echo "$data" | jq -r -c '.cursor')"
  echo "${data}" \
    | jq -c '.pushes
      | reverse[]
      | select(has("url"))
      | select(.direction == "self")'

  if [[ ! -z "${cursor}" ]] && [[ ! "${cursor}" == 'null' ]]; then
    _pb_fetch "${modified}" "${cursor}"
  fi

  _info "Fetching done."
}

_pb_format_entry() {
  local entry="$1"

  local title
  local url
  local ref_path

  title="$(echo "${entry}" | jq -r ".title // .url")"
  url="$(echo "${entry}" | jq -r ".url")"
  ref_path="references/$(_pb_create_filename "${title}").org"

  _info "Processing: '${title}'"
  echo ''
  echo "** [[file:${ref_path}][${title}]]" >> "$REF_FILE"
  echo ":PROPERTIES:" >> "$REF_FILE"
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
  local output="${ORG_DIR}/${ref_path}"
  if [[ "${url}" == *.pdf ]]; then
    _pb_store_pdf "$url" > "${output}"
  else
    _pb_store_page "$url" > "${output}"
  fi
  _info "Stored '${output}'"
}

_pb_create_filename() {
  echo "$1" | sed -e 's/[^A-Za-z0-9._-]/_/g' | tr '[:upper:]' '[:lower:]'
}

_pb_org() {
  local modified="$(( 100 + $(echo ${1:-1} | cut -d'.' -f1)))"
  for entry in $(_pb_fetch "${modified}"); do
    _pb_format_entry "${entry}"
  done
}

_pb_org_last() {
  grep ':MODIFIED:' "${REF_FILE}" | tail -n1 | cut -d ' ' -f2
}

_pb_store_pdf() {
  local url="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  curl --fail --silent --output "${tmp_dir}/file.pdf" "${url}"
  pdftotext -layout "${tmp_dir}/file.pdf" "${tmp_dir}/text.txt"
  _pb_page_header "${url}"
  sed 's/\f/\n/' "${tmp_dir}/text.txt"
  rm -rf "${tmp_dir}"
}

_pb_convert_page() {
  pandoc --columns 100 -f html -t org \
    | sed 's/^Title:/#+TITLE: /g; /\[\[\]\[\]\]/d; s/\]\[\]\]/\]\[url\]\] /g; /:PROPERTIES:/,/:END:/d; /#+BEGIN\_HTML/,/#+END\_HTML/d' \
    | sed '/^$/N;/^\n$/D' \
    | grep -v '<<readabilityBody>>'
}

_pb_page_header() {
  local url="$1"
  echo "#+STARTUP: showeverything"
  echo "#+CREATED_AT: $(date -u +%Y-%m-%dT%H:%M:%S%z)"
  echo "#+URL: ${url}"
}

_pb_store_page() {
  local url="$1"
  _pb_page_header "${url}"
  (breadability "${url}" | _pb_convert_page) # || echo 'Failed to fetch page.'
}

_pb_org "$(_pb_org_last)"
_info "Saved to '${REF_FILE}'"
