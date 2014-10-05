#!/usr/bin/env bash

set -o errexit
set -o pipefail

readonly now=$(/bin/date "+%Y-%m-%d")
echo "* ${now}"
/usr/local/bin/ghi \
  | /usr/bin/tail -n +2 \
  | /usr/local/bin/sed -r 's/ +/ /g; s/^/**/g; s/\[.*//g; s/@.*//g'
