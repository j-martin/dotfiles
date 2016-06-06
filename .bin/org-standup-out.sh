#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/slack"

_format () {
  local file="$1"
  grep '^\*' "$file" \
    | sed 's/^\*\* /- /g; s/^\* //g; s/\]\[/\|/g; s/\[\[/</g; s/\]\]/>/g'
}

_slack_post '#daily_standup' "$(_format "$HOME/.org/standup.org")"
