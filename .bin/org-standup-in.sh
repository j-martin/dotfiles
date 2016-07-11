#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/git"

_format () {
  jq -r '.[] | "** TODO [[\(.html_url)][\(.repository.full_name)#\(.number | tostring) - \(.title)]]" +
if (has("pull_request") and (.user.login != "j-martin")) then " :work:review:" else ":work:" end,
":PROPERTIES:",
":ID: " + (.id | tostring),
":END:",
.body'
}

_get_latest_entry () {
  grep '^\* ' ~/.org/standup.org \
    | tail -n1 \
    | cut -d' ' -f2
}

_generate_done () {
  _github "issues?assignee=$(_github_user)&state=closed&since=$(_get_latest_entry)" \
    | _format \
    | sed 's/^\*\* TODO/\*\* DONE/' \
    | tr -d '\r'
}

_generate_todo () {
  echo "* $(/bin/date "+%Y-%m-%d")"
  _github "issues?assignee=$(_github_user)" \
    | _format \
    | tr -d '\r'
}

echo ** --------------------
_generate_done
_generate_todo
