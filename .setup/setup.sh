#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -x

_macos_customizations () {
  sudo pmset -a standbydelay 86400
  sudo pmset -a sms 0

  # Remove all apps in dock
  defaults write com.apple.dock persistent-apps -array

  # Reduce spacing between menu bar items
  defaults -currentHost write -globalDomain NSStatusItemSpacing -int 12
  defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 8
  killall SystemUIServer

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

  # allow dragging windows by holding Cmd+Ctrl
  defaults write -g NSWindowShouldDragOnGesture YES

  # Disable the desktop
  defaults write com.apple.finder CreateDesktop false

  # Disable relaunching applications.
  defaults write -g ApplePersistence -bool no

  # Make key repeat faster.
  defaults write -g InitialKeyRepeat -int 15
  defaults write -g KeyRepeat -int 2

  killall Dock || true
  killall Finder || true

  # fix emacs ansi-term escape code, eterm-color.ti ships with emacs-plus
  tic -o ~/.terminfo "$(find "$(/opt/homebrew/bin/brew --prefix)/Cellar" -type f -name 'eterm-color.ti' | head -n 1)"
}

_macos_apps () {
  xcode-select --install || true
  NONINTERACTIVE=1 /bin/bash -c "$(curl --fail --silent --show-error --location https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  curl --fail --silent --show-error --location https://mise.run | sh
  "$HOME/.local/bin/mise" bootstrap packages apply
  "$HOME/.local/bin/mise" install
  # mise cannot evaluate emacs-plus: the formula requires sibling files from its tap.
  /opt/homebrew/bin/brew install d12frosted/emacs-plus/emacs-plus@31

  # The rest of the setup needs the freshly installed tools (npm, code, ...)
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

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
  xargs -n1 code --install-extension < "$HOME/.vscode/extensions/list"
}

if [[ "$(uname)" == 'Darwin' ]]; then
  _macos_apps
  _macos_customizations
elif [[ "$(uname)" == 'Linux' ]]; then
  _linux_apps
fi

_general
