#!/usr/bin/env bash

_info () {
  >&2 echo "[info] $@"
}

_warn () {
  >&2 echo "[warn] $@"
}

_production () {
  printf "\033]Ph501010\033\\"
}

_pick_first_col () {
  cut -d ' ' -f1
}

cached () {
  _cached "$@" 300
}

_cached () {
  local cmd="$1"
  local ttl="${2:-60}"
  local ts="$(( $(date +'%s') / $ttl ))"
  local filename="${TMPDIR}${ts}-$(echo "${cmd}" | shasum | cut -d' ' -f1)"
  if [[ "$NC" == '1' ]] || [[ ! -s "$filename" ]]; then
    eval "$cmd" | tee "$filename"
    _info "Cached '$cmd' to '$filename'."
  else
    cat "$filename"
    _warn "Used cached file '$filename'"
  fi
}

_with_fzf () {
  local app="$1"
  local prefix="$2"
  local file="$(_fzf "${prefix}" || echo "${prefix}")"
  if [[ -f "$file" ]]; then
    eval "$app $file"
  else
    echo "[error] '$file' is not a file."
  fi
}

_fzf () {
  fzf -1 -0 -q "$1"
}
