#!/usr/bin/env -S pkgx +gh +gum bash@5

set -o errexit
set -o pipefail
set -u
shopt -s inherit_errexit 2> /dev/null

IFS=$'\n\t'

_info() {
  echo >&2 "[info] $*"
}

_get() {
  local json="$1"
  local path="$2"
  jq -r "${path}" <<< "${json}"
}

_main() {
  local query="${1:-}"
  local current_user="${2:-}"
  if [[ -z "${current_user}" ]]; then
    current_user="$(gh api /user --jq '.login')"
  fi

  if [[ -n "${query}" ]]; then
    query="+${query}"
  fi

  query="is:pr+is:open+review-requested:${current_user}${query}"

  _info "Querying PRs for ${query}..."
  for pr_json in $(gh api "search/issues?q=${query}" | jq -c '.items[]'); do
    local url
    url="$(_get "${pr_json}" ".html_url")"
    if gum confirm "Approve PR? $(_get "${pr_json}" .title) ${url}/files?w=1"; then
      local repo
      repo="$(sed 's#.*github.com/##g; s#/pull/.*##;' <<< "${url}")"
      local pr_number
      pr_number="$(_get "${pr_json}" ".number")"
      gh pr review --repo "${repo}" "${pr_number}" --approve
    fi
  done
}

_main "$@"
