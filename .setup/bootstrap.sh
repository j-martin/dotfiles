#!/usr/bin/env bash
# Install the dotfiles into $HOME as a git worktree backed by ~/.files.git.
#
#   curl --fail --silent --show-error --location https://raw.githubusercontent.com/j-martin/dotfiles/main/.setup/bootstrap.sh | bash
#
# Creates the ~/.ssh/github key when missing and walks through adding it to GitHub.
# Existing files that would be overwritten are moved to ~/.files-backup/<timestamp>/.
# Then runs ~/.setup/setup.sh, unless DOTFILES_SKIP_SETUP=true.
# Safe to rerun, e.g. after a failed submodule update.

set -o errexit
set -o pipefail
set -u

readonly remote="${DOTFILES_REMOTE:-git@github.com:j-martin/dotfiles.git}"
readonly branch="${DOTFILES_BRANCH:-main}"
readonly git_dir="${HOME}/.files.git"
readonly ssh_key="${HOME}/.ssh/github"
readonly ssh_keys_url='https://github.com/settings/ssh/new'

# ~/.ssh/config is not installed yet, so point git at the key explicitly
export GIT_SSH_COMMAND="ssh -F /dev/null -i '${ssh_key}' -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

__home() {
  git --work-tree="${HOME}" --git-dir="${git_dir}" "$@"
}

# stdin is the script itself when piped from curl, so prompts read the terminal
__prompt() {
  local message="$1"
  local default="${2:-}"
  local answer
  read -r -p "${message}" answer < /dev/tty
  echo "${answer:-${default}}"
}

__github_authenticated() {
  local output
  output="$(ssh -T -F /dev/null -i "${ssh_key}" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes git@github.com 2>&1 || true)"
  [[ "${output}" == *'successfully authenticated'* ]]
}

__ssh_key() {
  if [[ ! -f "${ssh_key}" ]]; then
    local email
    email="$(__prompt 'Email for the SSH key [jm@jmartin.ca]: ' 'jm@jmartin.ca')"
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    ssh-keygen -t ed25519 -C "${email}" -f "${ssh_key}" < /dev/tty
  fi

  if [[ "$(uname)" == 'Darwin' ]]; then
    # Must use the system ssh-add, Homebrew's lacks the keychain option
    /usr/bin/ssh-add --apple-use-keychain "${ssh_key}" < /dev/tty
  else
    ssh-add "${ssh_key}" < /dev/tty || true
  fi

  while ! __github_authenticated; do
    echo "Add this key to GitHub: ${ssh_keys_url}"
    cat "${ssh_key}.pub"
    if [[ "$(uname)" == 'Darwin' ]]; then
      pbcopy < "${ssh_key}.pub"
      echo "(copied to the clipboard)"
      open "${ssh_keys_url}"
    elif command -v xdg-open > /dev/null; then
      xdg-open "${ssh_keys_url}" > /dev/null 2>&1 || true
    fi
    __prompt 'Press Enter once the key is added to GitHub...' > /dev/null
  done
  echo "[ok] GitHub accepts ${ssh_key}"
}

__check_git() {
  # On a fresh macOS, /usr/bin/git is a stub until the Command Line Tools are installed
  if [[ "$(uname)" == 'Darwin' ]] && ! xcode-select --print-path > /dev/null 2>&1; then
    xcode-select --install || true
    echo >&2 "[fatal] Install the Command Line Tools, then rerun this script."
    exit 1
  fi
  if ! command -v git > /dev/null; then
    echo >&2 "[fatal] git is required."
    exit 1
  fi
}

__backup_conflicts() {
  local backup_dir file
  backup_dir="${HOME}/.files-backup/$(date '+%Y%m%d%H%M%S')"
  while IFS= read -r file; do
    if [[ -e "${HOME}/${file}" || -L "${HOME}/${file}" ]]; then
      mkdir -p "$(dirname "${backup_dir}/${file}")"
      mv "${HOME}/${file}" "${backup_dir}/${file}"
      echo "[backup] ${file}"
    fi
  done < <(__home ls-tree -r --name-only "origin/${branch}")
}

__copy_reference() {
  local source_file="$1"
  local target="$2"
  if [[ -e "${target}" ]]; then
    echo "[ok]     ${target} exists, not overwriting"
    return 0
  fi
  mkdir -p "$(dirname "${target}")"
  cp "${source_file}" "${target}"
  echo "[copied] ${target}"
}

_main() {
  __check_git
  __ssh_key
  # git submodule must run from inside the work tree
  cd "${HOME}"

  if [[ ! -d "${git_dir}" ]]; then
    __home init --quiet
  fi
  if ! __home remote get-url origin > /dev/null 2>&1; then
    __home remote add origin "${remote}"
  fi
  __home fetch origin "${branch}"
  # Safe to rerun: only check out while the branch is still unborn
  if ! __home rev-parse --verify --quiet HEAD > /dev/null; then
    __backup_conflicts
    __home checkout --track "origin/${branch}"
  fi
  __home submodule update --init
  __copy_reference "${HOME}/.gitconfig.ref" "${HOME}/.gitconfig"
  __copy_reference "${HOME}/.ssh.config" "${HOME}/.ssh/config"

  echo "[ok] Dotfiles installed"

  if [[ "${DOTFILES_SKIP_SETUP:-}" != 'true' ]]; then
    # setup.sh prompts for sudo and chsh, which need the terminal
    "${HOME}/.setup/setup.sh" < /dev/tty
  fi
}

_main "$@"
