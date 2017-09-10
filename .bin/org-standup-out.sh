#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/slack"

_format () {
  local file="$1"
  sed '0,/^\* -------/d' "$file" \
    | grep '^\*' \
    | grep -v '^\*\* -------' \
    | grep -vE '^\*\*\*+' \
    | sed 's/^\* //g; s/\]\[/\|/g; s/\[\[/</g; s/\]\]/>/g'
}

if [[ -n "$DEBUG" ]]; then
  _format "$HOME/.org/standup.org"
else
  _slack_post '#team_platform' "$(_format "$HOME/.org/standup.org")"
fi
