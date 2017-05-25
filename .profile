#!/usr/bin/env bash

export WORK="$HOME/Work"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export CDPATH=".:$HOME:$WORK"
export VISUAL="emacsclient"
export GPG_TTY="$(tty)"

test -f "$HOME/.private/.profile" && source "$HOME/.private/.profile"

source "$HOME/.functions/all"
source "$HOME/.aliases"

test -d "$HOME/.org/references" || enc

export GOPATH="$HOME/.go"
export PATH="$HOME/.venv/bin:$GOPATH/bin:/usr/local/sbin:$HOME/.npm/bin:/usr/local/bin:$HOME/.bin:/usr/bin:/bin:/usr/sbin:/sbin"

test -e /usr/libexec/java_home && export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"
test -e /usr/local/bin/nvim && export EDITOR='/usr/local/bin/nvim'

export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules"
export PAGER='less -SRi'
export HOSTNAME="$HOST"
export FZF_DEFAULT_COMMAND='ag --hidden --path-to-ignore ~/.agignore  -l -g ""'
unset SSL_CERT_FILE

export SDKMAN_DIR="/Users/benchemployee/.sdkman"
[[ -s "/Users/jm/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/jm/.sdkman/bin/sdkman-init.sh"

if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
  exec startx
fi
