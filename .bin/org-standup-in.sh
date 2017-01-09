#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/git"

_format() {
  jq -r '.[] | "** TODO [[\(.html_url)][\(.repository.full_name)#\(.number | tostring) - \(.title)]]" +
if (has("pull_request") and (.user.login != "j-martin")) then " :review:" else "" end,
":PROPERTIES:",
":ID: " + (.id | tostring),
":END:"
'
}

_get_latest_entry () {
  grep '^\* ' ~/.org/standup.org \
    | tail -n1 \
    | cut -d' ' -f2
}

_generate_done() {
  local user="$(_github_user)"
  local last_entry="$(_get_latest_entry)"

  _github "issues?assignee=${user}&state=closed&since=${last_entry}" \
    | _format \
    | sed 's/^\*\* TODO/\*\* DONE/' \
    | tr -d '\r'

  _github "issues?creator=${user}&state=closed&since=${last_entry}" \
    | _format \
    | sed 's/^\*\* TODO/\*\* DONE/' \
    | grep ':review:' || echo '' \
    | sed 's/:review://g' \
    | tr -d '\r'
}

_generate_todo() {
  echo "* $(/bin/date "+%Y-%m-%d")"
  _github "issues?assignee=$(_github_user)" \
    | _format \
    | tr -d '\r'
}

_generate_done
_generate_todo
