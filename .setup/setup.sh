#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -x

_macos_customizations() {
  sudo pmset -a standbydelay 86400
  sudo pmset -a sms 0

  # Remove all apps in dock
  defaults write com.apple.dock persistent-apps -array

  # Reduce spacing between menu bar items
  defaults -currentHost write -globalDomain NSStatusItemSpacing -int 12
  defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 8
  killall SystemUIServer

  # Speed up Mission Control animation
  defaults write com.apple.dock expose-animation-duration -float 0.1
  # Remove Dock show/hide animation
  defaults write com.apple.dock autohide-time-modifier -float 0
  # Remove delay before the Dock appears on hover
  defaults write com.apple.dock autohide-delay -float 0
  # Group windows by application in Mission Control
  defaults write com.apple.dock "expose-group-by-app" -bool true
  # Automatically hide the Dock
  defaults write com.apple.dock autohide -bool true
  # Remove delay before the Dock appears on hover (duplicate)
  defaults write com.apple.dock autohide-delay -float 0
  # Remove Dock show/hide animation (duplicate)
  defaults write com.apple.dock autohide-time-modifier -float 0
  # Disable accent popup on key hold, enabling key repeat instead
  defaults write -g ApplePressAndHoldEnabled -bool false
  # Don't create .DS_Store files on network volumes
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  # Allow selecting text in Quick Look previews
  defaults write com.apple.finder QLEnableTextSelection -bool true
  # Remove Finder autohide delay (likely no effect, Dock-only key)
  defaults write com.apple.finder autohide-delay -float 0
  # Don't animate app icons bouncing when launching from the Dock
  defaults write com.apple.dock launchanim -bool false

  # Trackpad pointer speed (beyond the System Settings max)
  defaults write -g com.apple.trackpad.scaling -float 20.0
  # Mouse wheel scrolling speed
  defaults write -g com.apple.scrollwheel.scaling -float 20.0
  # Trackpad scrolling speed
  defaults write -g com.apple.trackpad.scrolling -float 20.0

  # Mouse pointer speed
  defaults write -g com.apple.mouse.scaling 2.5

  # Disable font smoothing (thinner text rendering)
  defaults write NSGlobalDomain AppleFontSmoothing -int 0
  # Require password after sleep or screen saver
  defaults write com.apple.screensaver askForPassword -int 1
  # ...immediately, with no grace period
  defaults write com.apple.screensaver askForPasswordDelay -int 0
  # Disable automatic keyboard backlight adjustment based on ambient light
  sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Keyboard Enabled" -bool false
  # Expand save dialogs by default
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  # Expand print dialogs by default
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
  # Disable smart quotes
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  # Disable smart dashes
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  # Use UTF-8 only in Terminal.app
  defaults write com.apple.terminal StringEncodings -array 4
  # Use the "Pro" theme for new Terminal.app windows
  defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
  # Use the "Pro" theme for Terminal.app startup windows
  defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
  # Remove Launchpad show animation
  defaults write com.apple.dock springboard-show-duration -int 0
  # Remove Launchpad hide animation
  defaults write com.apple.dock springboard-hide-duration -int 0
  # iTerm2: send arrow keys on mouse scroll in alternate screen apps (less, vim, ...)
  defaults write com.googlecode.iterm2 AlternateMouseScroll -bool true
  # Oni editor: enable key repeat instead of accent popup on key hold
  defaults write com.extropy.oni ApplePressAndHoldEnabled -bool false
  # Allow Time Machine backups to unsupported network volumes
  defaults write com.apple.systempreferences TMShowUnsupportedNetworkVolumes 1
  # Chrome: show "Always open" checkbox on external protocol dialogs
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

_macos_apps() {
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

_main() {
  chmod 700 "$HOME/.gnupg"
  chmod -R 600 "$HOME/.gnupg"

  _macos_apps
  _macos_customizations

  xargs -n1 code --install-extension < "$HOME/.vscode/extensions/list"

}

_main
