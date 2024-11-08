# Path to your oh-my-zsh configuration.
#
[[ $TERM == "dumb" ]] && unsetopt zle && PS1='$ ' && return
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"
ZSH_CUSTOM="$HOME/.oh-my-zsh-custom"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Uncomment this to disable bi-weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment to change how often before auto-updates occur? (in days)
# export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want to disable command autocorrection
# DISABLE_CORRECTION="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment following line if you want to  shown in the command execution time stamp
# in the history command output. The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|
# yyyy-mm-dd
# HIST_STAMPS="mm/dd/yyyy"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)

plugins=(
  autojump
  # brew
  # cargo
  common-aliases
  # dircycle
  # dirhistory
  docker
  # gradle
  git
  gitfast
  # github
  # kubectl
  # man
  # fd
  # fzf
  # node
  macos
  ripgrep
  # terraform
  # vault
  zsh-autosuggestions
  # z
)

source "$ZSH/oh-my-zsh.sh"

# Fixes for zsh-autosuggestions slow paste
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=5
unset zle_bracketed_paste

setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

export HISTFILESIZE=1000000
export HISTSIZE=1000000
export HISTCONTROL=ignoreboth
export HISTIGNORE='ls:bg:fg:history'

# User configuration
bindkey -e
export KEYTIMEOUT=1

bindkey '^[[1;9C' forward-word
bindkey '^[[1;9D' backward-word

source "$HOME/.base"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[[ -f /opt/dev/sh/chruby/chruby.sh ]] && type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; }
[ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

export PATH="/opt/homebrew/opt/ruby/bin:$PATH"

[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/jm/.bin/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/jm/.bin/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/jm/.bin/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/jm/.bin/google-cloud-sdk/completion.zsh.inc'; fi

# bun completions
[ -s "/Users/jm/.bun/_bun" ] && source "/Users/jm/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
