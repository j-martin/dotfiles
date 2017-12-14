#!/usr/bin/env bash

export WORK="$HOME/code/benchlabs"
export GOPATH="$HOME/code/go"
export GOWORK="$GOPATH/src/github.com/benchlabs/"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export CDPATH=".:$HOME:$HOME/code/j-martin:$WORK:$GOWORK"
export VISUAL="emacsclient"
export GPG_TTY="$(tty)"

__encfs() {
  local root_dir="$1"
  local mount_point="$2"
  local mount_file="${mount_point}/.mounted"
  if [[ ! -f "${mount_file}" ]]; then
    echo "Mounting: ${mount_point}"
    encfs "${root_dir}" "${mount_point}" && touch "${mount_file}"
  fi
}

__encfs "$HOME/Dropbox/Storage" "$HOME/.storage"
__encfs "$HOME/Library/.chrome" "$HOME/Library/Application Support/Google/Chrome"

test -f "$HOME/.private/.profile" && source "$HOME/.private/.profile"

source "$HOME/.functions/all"
source "$HOME/.aliases"

export PATH="$GOPATH/bin:/usr/local/sbin:$HOME/.npm/bin:/usr/local/bin:$HOME/.bin:/usr/bin:/bin:/usr/sbin:/sbin"

test -e /usr/libexec/java_home && export JAVA_HOME="$(/usr/libexec/java_home -v 9)"
test -e /usr/local/bin/nvim && export EDITOR='/usr/local/bin/nvim'

# export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules"
export PAGER='less -SRi'
export HOSTNAME="$HOST"
# export FZF_DEFAULT_COMMAND='ag --hidden --path-to-ignore ~/.agignore  -l -g ""'
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'
unset SSL_CERT_FILE

export SDKMAN_DIR="/Users/jm/.sdkman"
[[ -s "/Users/jm/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/jm/.sdkman/bin/sdkman-init.sh"

if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
  exec startx
fi

export PATH="$HOME/.cargo/bin:$PATH"
