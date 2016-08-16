#!/usr/bin/env bash

set -o errexit
set -o pipefail

_macos_customizations () {
  defaults write com.apple.dock expose-animation-duration -float 0.1
  defaults write com.apple.dock "expose-group-by-app" -bool true
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0
  defaults write -g ApplePressAndHoldEnabled -bool false
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.finder QLEnableTextSelection -bool true
  defaults write com.apple.finder autohide-delay -float 0; Killall finder
  defaults write -g com.apple.trackpad.scaling -float 12.0
  defaults write -g com.apple.mouse.scaling 2.5
  defaults write NSGlobalDomain AppleFontSmoothing -int 0
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0
  sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Keyboard Enabled" -bool false
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
  sudo pmset -a standbydelay 86400
  sudo pmset -a sms 0
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write com.apple.terminal StringEncodings -array 4
  defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
  defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
  defaults write com.apple.dock springboard-show-duration -int 0
  defaults write com.apple.dock springboard-hide-duration -int 0
  defaults write com.googlecode.iterm2 AlternateMouseScroll -bool true
  defaults write com.apple.LaunchServices LSHandlers -array-add '{LSHandlerContentType=public.plain-text;LSHandlerRoleAll=com.sublimetext.3;}'
  killall Dock
  ln -s "$HOME" '/Users/jm'

  # fix emacs ansi-term escape code
  tic -o ~/.terminfo "$(find /usr/local/Cellar -type f -name '*.ti' | head)"
}

_macos_apps () {
  xcode-select --install
  brew bundle --global
}

_linux_apps () {
  add-apt-repository ppa:git-core/ppa
  apt-add-repository ppa:ubuntu-elisp/ppa
  add-apt-repository ppa:neovim-ppa/unstable
  apt-get update
  apt-get install zsh git silversearcher-ag neovim
}

_general () {
  npm install -g vmd eslint
  pip install -r requirements.txt
  curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
  git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
}

if [[ "$(uname)" == 'Darwin' ]]; then
  _macos_apps
  _macos_customizations
elif [[ "$(uname)" == 'Linux' ]]; then
  _linux_apps
fi

_general
