#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/git"

_format () {
  jq -r '.[] | "** TODO " + .repository.full_name + "#" + (.number | tostring) + "-" + .title + " [[" + .html_url + "][view]]",
":PROPERTIES:",
":ID: " + (.id | tostring),
":END:",
.body'
}

_generate () {
  echo "* $(/bin/date "+%Y-%m-%d")"
  _github "issues?assignee=$(_github_user)" | _format | tr -d '\r'
}

_generate >> "$HOME/.org/standup.org"
_info 'Standup updated.'
