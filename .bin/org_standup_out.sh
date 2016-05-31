#!/usr/bin/env bash

set -o errexit
set -o pipefail

source "$HOME/.functions/base"
source "$HOME/.functions/slack"

_slack_post '#testing' "$(grep '^\*\*' "$HOME/.org/standup.org")"
_info 'Standup posted to Slack.'
