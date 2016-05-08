#!/usr/bin/env bash

_git_repo () {
  git config --get remote.origin.url \
    | cut -d ':' -f2 \
    | cut -d '.' -f1 \
    | head -n1
}

_git_repo_name () {
  git config --get remote.origin.url \
    | cut -d/ -f2 \
    | cut -d. -f1
}

_git_current_branch () {
  git symbolic-ref --short -q HEAD
}
_git_current_branch_url () {
  _git_current_branch | sed "s/#/%23/g"
}

_git_current_issue_number () {
  _git_current_branch | ((grep -o '.*#[0-9]*') || echo '')
}

_git_pick_branch_no_origin() {
  _git_pick_branch | sed 's/origin\///g'
}

_git_pick_branch () {
  git branch --all | fzf | sed 's/remotes\///g' | cut -c 3-
}

_git_pick_commit () {
  git log --oneline --all | head -n 100 | _fzf "$1" | _pick_first_col
}

_git_new_branch () {
  local name="$1"
  git checkout -b $(echo "$name" | tr ' :,.+^&*()[]@$%' '-' | sed -r 's/-+/-/g')
}

_github () {
  local endpoint="$1"
  curl --fail --silent -H "Authorization: token $GH_TOKEN" "https://api.github.com/$endpoint"
}

_github_search_issues() {
  local label="$1"
  _github "search/issues?q=label:$label&per_page=300"
}

_github_repos () {
  _github 'user/repos?per_page=200'
}

_github_pick_repo () {
  _github_repos | jq -r '.[].git_url' | _fzf $1
}

_github_repo_issues () {
  _github "repos/$(_git_repo)/issues" | _github_format_issues
}

_github_issues() {
  _github "issues?assignee=$(_github_user)" \
    | jq -r '.[] | .repository.full_name + "#" + (.number | tostring) + "-" + .title'
}

_github_issues_search() {
  local label="$1"
  _github "search/issues?q=label:$label&per_page=300"
}

_github_format_issues () {
  jq -r '.[] | ["#" + (.number | tostring), .title] | join("-")' \
}

_github_format_search_issues () {
  jq -r '.items[] | [(.repository_url | sub(".*/"; "")) + "#" + (.number | tostring),
    .title, .state, ([.labels[].name] | join(", ")), .assignee.login] | join("¡")' \
      | column -s '¡' -t
}

_github_user () {
  git config --get github.user
}

_github_repo_assigned_issues () {
  _github "repos/$(_git_repo)/issues?assignee=$(_github_user)" \
    | _github_format_issues
}
