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
_format_wrike() {
  local state="$1"
  jq -r ".data[] | \"** ${state} [[\(.permalink)][\(.title)]]\""
}

_format_github() {
  local state="${1:-TODO}"
  local tags="$2"
  jq -r ".items[] | \"** ${state} [[\(.html_url)][\(.repository_url)#\(.number | tostring) - \(.title)]] ${tags}\",
\":PROPERTIES:\",
\":ID: \" + (.id | tostring),
\":END:\"
" \
    | sed "s#https://api.github.com/repos/$(_github_org)/##g" \
    | tr -d '\r'
}

_generate_previous() {
  local user="$1"
  local last_entry="$(_get_latest_entry)"
  _wrike "tasks/?responsibles=[${user}]&completedDate={\"start\":\"${last_entry}T08:00:00Z\"}" \
    | _format_wrike 'DONE'

  _github "search/issues?q=author:$(_github_user)+closed:>=${last_entry}" \
    | _format_github 'DONE'

  _github "search/issues?q=author:$(_github_user)+state:open+created:>=${last_entry}" \
    | _format_github 'TODO' ':merge:'

  _github "search/issues?q=type:pr+reviewed-by:$(_github_user)+closed:>=${last_entry}" \
    | _format_github 'DONE' ':review:'
}

_generate_today() {
  local user="$1"
  echo "* $(/bin/date "+%Y-%m-%d")"

  _github "search/issues?q=type:pr+review-requested:$(_github_user)+is:open" \
    | _format_github 'TODO' ':review:'

  _wrike "tasks/?responsibles=[${user}]&status=[Active]" \
    | _format_wrike 'TODO'
}

_main() {
  local user="$(_wrike_user)"
  _generate_previous "${user}"
  _generate_today "${user}"
}

_main
