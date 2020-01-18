#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -u

_main() {
  cd "$(mktemp -d)"
  git clone --recurse-submodules https://github.com/Koihik/LuaFormatter.git
  cd LuaFormatter
  cmake .
  make
  make install
}

_main "$@"
