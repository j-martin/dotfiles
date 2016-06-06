#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/git"

_format () {
  jq -r '.[] | "\(.repository.full_name)#\(.number | tostring) - \(.title)"'
}

_generate () {
  _github "issues?assignee=$(_github_user)" | _format | tr -d '\r'
}

_generate 
