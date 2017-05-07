#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/slack"

_format () {
  local file="$1"
  grep '^\*' "$file" \
    | sed 's/^\*\* DONE/  :white_check_mark:/; s/^\*\* TODO/  :lower_left_paintbrush:/' \
    | sed 's/^\* //g; s/\]\[/\|/g; s/\[\[/</g; s/\]\]/>/g' \
    | sed 's/:review:/:eyes:/g; s/:merge:/:hammer:/g'
}

# _format "$HOME/.org/standup.org"
_slack_post '#dev_standup' "$(_format "$HOME/.org/standup.org")"
