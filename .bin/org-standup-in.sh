#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/git"
source "$HOME/.functions/wrike"

_get_latest_entry () {
  grep '^\* ' ~/.org/standup.org \
    | tail -n1 \
    | cut -d' ' -f2
}
_format() {
  local state="$1"
  jq -r ".data[] | \"** ${state} [[\(.permalink)][\(.title)]]\""
}

_format_github() {
  jq -r '.items[] | "** TODO [[\(.html_url)][\(.repository_url)#\(.number | tostring) - \(.title)]] :review:",
":PROPERTIES:",
":ID: " + (.id | tostring),
":END:"
' \
    | sed "s#https://api.github.com/repos/$(_github_org)/##g"
}
_generate_done() {
  local user="$1"
  local last_entry="$(_get_latest_entry)"
  _wrike "tasks/?responsibles=[${user}]&completedDate={\"start\":\"${last_entry}T08:00:00Z\"}" \
    | _format 'DONE'

  _github "search/issues?q=type:pr+reviewed-by:$(_github_user)+closed:>${last_entry}" \
    | _format_github \
    | sed 's/^\*\* TODO/\*\* DONE/' \
    | tr -d '\r'
}

_generate_todo() {
  local user="$1"
  echo "* $(/bin/date "+%Y-%m-%d")"

  _github "search/issues?q=type:pr+review-requested:$(_github_user)+is:open" \
    | _format_github \
    | tr -d '\r'

  _wrike "tasks/?responsibles=[${user}]&status=[Active]" \
    | _format 'TODO'
}

_main() {
  local user="$(_wrike_user)"
  _generate_done "${user}"
  _generate_todo "${user}"
}

_main
