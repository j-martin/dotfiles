#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -x

BINPATH="$(dirname "$0")"

_macos_customizations () {
  sudo pmset -a standbydelay 86400
  sudo pmset -a sms 0

  defaults write com.apple.dock expose-animation-duration -float 0.1
  defaults write com.apple.dock autohide-time-modifier -float 0
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock "expose-group-by-app" -bool true
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0
  defaults write -g ApplePressAndHoldEnabled -bool false
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.finder QLEnableTextSelection -bool true
  defaults write com.apple.finder autohide-delay -float 0
  defaults write com.apple.dock launchanim -bool false

  defaults write -g com.apple.trackpad.scaling -float 20.0
  defaults write -g com.apple.scrollwheel.scaling -float 20.0
  defaults write -g com.apple.trackpad.scrolling -float 20.0

  defaults write -g com.apple.mouse.scaling 2.5

  defaults write NSGlobalDomain AppleFontSmoothing -int 0
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0
  sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Keyboard Enabled" -bool false
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write com.apple.terminal StringEncodings -array 4
  defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
  defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
  defaults write com.apple.dock springboard-show-duration -int 0
  defaults write com.apple.dock springboard-hide-duration -int 0
  defaults write com.googlecode.iterm2 AlternateMouseScroll -bool true
  defaults write com.extropy.oni ApplePressAndHoldEnabled -bool false
  defaults write com.apple.systempreferences TMShowUnsupportedNetworkVolumes 1
  defaults write com.google.Chrome ExternalProtocolDialogShowAlwaysOpenCheckbox -bool true

  # Disable the desktop
  defaults write com.apple.finder CreateDesktop false

  # Disable relauching application.
  defaults write -g ApplePersistence -bool no

  # Make key repeat faster.
  defaults write -g InitialKeyRepeat -int 15
  defaults write -g KeyRepeat -int 2

  killall Dock || true
  Killall Finder || true

  # fix emacs ansi-term escape code
  tic -o ~/.terminfo "$(find /usr/local/Cellar -type f -name '*.ti' | head -n 1)"
}

_macos_apps () {
  xcode-select --install || true
  brew bundle --global

  brew cleanup
  brew cask cleanup

  which zsh \
    | head -n1 \
    | sudo tee -a /etc/shells
}

_linux_apps () {
  add-apt-repository ppa:git-core/ppa
  apt-add-repository ppa:ubuntu-elisp/ppa
  add-apt-repository ppa:neovim-ppa/unstable
  apt-get update
  apt-get install zsh git silversearcher-ag neovim
}

_general () {
  chmod 700 "$HOME/.gnupg"
  chmod -R 600 "$HOME/.gnupg"

  chsh -s "$(grep /zsh$ /etc/shells | tail -1)"
  npm install -g vmd
  pip3 install -r "$BINPATH/requirements.txt"
  xargs -n1 code --install-extension < "$HOME/.vscode/extensions/list"
}

_go_specific () {
  # mostly imports for emacs
  go get -u -v github.com/nsf/gocode
  go get -u -v github.com/rogpeppe/godef
  go get -u -v golang.org/x/tools/cmd/guru
  go get -u -v golang.org/x/tools/cmd/gorename
  go get -u -v golang.org/x/tools/cmd/goimports
}

if [[ "$(uname)" == 'Darwin' ]]; then
  _macos_customizations
elif [[ "$(uname)" == 'Linux' ]]; then
  _linux_apps
fi

_general
