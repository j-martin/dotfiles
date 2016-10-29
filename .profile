#!/usr/bin/env bash

export WORK="$HOME/Work"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export CDPATH=".:$HOME:$WORK"

source "$HOME/.private/.profile"
source "$HOME/.functions/all"
source "$HOME/.aliases"

export GOPATH="$HOME/.go"
export PATH="$HOME/.venv/bin:$GOPATH/bin:/usr/local/sbin:$HOME/.npm/bin:/usr/local/bin:$HOME/.bin:/usr/bin:/bin:/usr/sbin:/sbin"

test -e /usr/libexec/java_home && export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"
test -e /usr/local/bin/nvim && export EDITOR='/usr/local/bin/nvim'
export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules"
export PAGER='less -SRi'
export HOSTNAME="$HOST"
export FZF_DEFAULT_COMMAND='ag --hidden --path-to-ignore ~/.agignore  -l -g ""'
unset SSL_CERT_FILE

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/benchemployee/.sdkman"
[[ -s "/Users/benchemployee/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/benchemployee/.sdkman/bin/sdkman-init.sh"
