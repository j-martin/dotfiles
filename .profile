#!/usr/bin/env bash

export WORK="$HOME/Work"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export CDPATH=".:$HOME:$WORK"

source "$HOME/.private/.profile"
source "$HOME/.functions/all"
source "$HOME/.aliases"

export GOPATH="$HOME/.go"
export PATH="$PATH:$GOPATH/bin"
export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"
export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules"
export EDITOR='/usr/local/bin/nvim'
export PAGER='less -SRi'
export HOSTNAME="$HOST"
export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -l -g ""'
unset SSL_CERT_FILE
