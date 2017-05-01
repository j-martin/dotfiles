#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/slack"

_format () {
  local file="$1"
  grep '^\*' "$file" \
    | sed 's/^\*\* DONE/  :heavy_check_mark:/; s/^\*\* TODO/  :construction:/' \
    | sed 's/^\* //g; s/\]\[/\|/g; s/\[\[/</g; s/\]\]/>/g' \
    | sed 's/:review:/:passport_control:/g; s/:merge:/:hammer:/g'
}

# _format "$HOME/.org/standup.org"
_slack_post '#dev_standup' "$(_format "$HOME/.org/standup.org")"
