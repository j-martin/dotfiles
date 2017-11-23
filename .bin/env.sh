#!/usr/bin/env bash
# Entrypoint for emacs

BINPATH="$(dirname "$0")"

source "${BINPATH}/../.functions/all"
source "${BINPATH}/../.private/.profile"

set -o errexit
set -o pipefail

"$@"
