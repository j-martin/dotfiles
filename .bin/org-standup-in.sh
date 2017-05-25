#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/git"

BINPATH="$(dirname "$0")"

_get_latest_entry () {
  grep '^\* ' ~/.org/standup.org \
    | tail -n1 \
    | cut -d' ' -f2
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
  local last_entry="$(_get_latest_entry)"
  echo '** ---------------------'
  pipenv run python org-jira.py --query "assignee = currentuser() AND resolutiondate > ${last_entry}"

  _github "search/issues?q=author:$(_github_user)+closed:>=${last_entry}" \
    | _format_github 'DONE'

  _github "search/issues?q=author:$(_github_user)+state:open+created:>=${last_entry}" \
    | _format_github 'TODO' ':merge:'

  _github "search/issues?q=type:pr+reviewed-by:$(_github_user)+closed:>=${last_entry}" \
    | _format_github 'DONE' ':review:'
}

_generate_today() {
  echo "* $(/bin/date "+%Y-%m-%d")"

  _github "search/issues?q=type:pr+review-requested:$(_github_user)+is:open" \
    | _format_github 'TODO' ':review:'

  pipenv run python org-jira.py
}

_main() {
  pushd "${BINPATH}" > /dev/null
  _generate_previous
  _generate_today
  popd > /dev/null
 }

_main
