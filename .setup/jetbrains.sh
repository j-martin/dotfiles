#!/usr/bin/env bash
# Symlink the shared External Tools config into every installed JetBrains IDE.
# An existing regular file is kept as "External Tools.xml.bak".
# BSD ln/mkdir/mv on macOS have no long options.

set -o errexit
set -o pipefail
set -u

readonly source_file="${HOME}/Library/Preferences/IntelliJIdeaCurrent/tools/External Tools.xml"
readonly jetbrains_dir="${HOME}/Library/Application Support/JetBrains"
readonly file_name='External Tools.xml'

__link() {
  local config_dir="$1"
  local target="${config_dir}/tools/${file_name}"

  if [[ -L "${target}" && "$(readlink "${target}")" == "${source_file}" ]]; then
    echo "[ok]     ${target}"
    return 0
  fi

  mkdir -p "${config_dir}/tools"
  if [[ -e "${target}" && ! -L "${target}" ]]; then
    mv -f "${target}" "${target}.bak"
    echo "[backup] ${target}.bak"
  fi
  ln -s -f "${source_file}" "${target}"
  echo "[linked] ${target}"
}

_main() {
  if [[ ! -f "${source_file}" ]]; then
    echo >&2 "[fatal] Missing ${source_file}"
    exit 1
  fi

  local config_dir found='false'
  # IDE config dirs are versioned, e.g. GoLand2026.2, IdeaIC2025.2
  for config_dir in "${jetbrains_dir}"/*[0-9][0-9][0-9][0-9].[0-9]*/; do
    [[ -d "${config_dir}" ]] || continue
    found='true'
    __link "${config_dir%/}"
  done

  if [[ "${found}" == 'false' ]]; then
    echo >&2 "[warn] No JetBrains IDE config found in ${jetbrains_dir}"
  fi
}

_main "$@"
