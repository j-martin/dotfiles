#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -x

readonly EDITOR_APP="$HOME/Applications/Editor.app"
readonly EDITOR_APP_ID='com.github.j-martin.editor'
readonly LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'

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

# Editor.app forwards double-clicked files to ~/.bin/editor, which opens them in
# Emacs (emacsclient) or runs them when they are executable.
_macos_editor_app() {
  local app="${EDITOR_APP}"
  rm -rf "${app}"
  mkdir -p "$(dirname "${app}")"
  osacompile -o "${app}" << 'EOF'
on open theItems
  set args to ""
  repeat with anItem in theItems
    set args to args & " " & quoted form of POSIX path of anItem
  end repeat
  do shell script "\"$HOME/.bin/editor\" --finder" & args & " > /dev/null 2>&1 &"
end open
EOF
  local info="${app}/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "${EDITOR_APP_ID}" "${info}"
  plutil -replace CFBundleName -string 'Editor' "${info}"
  plutil -replace LSUIElement -bool true "${info}"
  plutil -replace CFBundleDocumentTypes -json '[{
    "CFBundleTypeName": "Document",
    "CFBundleTypeRole": "Editor",
    "LSHandlerRank": "Alternate",
    "LSItemContentTypes": ["public.data", "public.text", "public.unix-executable"]
  }]' "${info}"
  # Editing Info.plist invalidates the applet signature.
  codesign --force --deep --sign - "${app}"
  "${LSREGISTER}" -f -R "${app}"
}

_macos_default_apps() {
  # public.data covers files without a more specific type (e.g. no extension).
  local targets=(
    public.data public.unix-executable public.text public.plain-text public.utf8-plain-text
    public.source-code public.script public.shell-script public.json public.xml
    public.yaml public.comma-separated-values-text public.log net.daringfireball.markdown
    .md .org .txt .log .conf .cfg .ini .toml .yaml .yml .json .env .lua .el .sh .zsh .bash
  )

  # `duti -s` fails (error -50) for public.data and extensions without a declared
  # type on recent macOS, so first write the handlers like Finder's "Change All" does.
  /usr/bin/python3 - "${EDITOR_APP_ID}" "${targets[@]}" << 'EOF'
import os, plistlib, sys

path = os.path.expanduser(
    "~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
)
bundle_id, targets = sys.argv[1], sys.argv[2:]
plist = {}
if os.path.exists(path):
    with open(path, "rb") as f:
        plist = plistlib.load(f)

handlers = []
for target in targets:
    if target.startswith("."):
        handlers.append({
            "LSHandlerContentTag": target[1:],
            "LSHandlerContentTagClass": "public.filename-extension",
        })
    else:
        handlers.append({"LSHandlerContentType": target})

keys = {(h.get("LSHandlerContentType"), h.get("LSHandlerContentTag")) for h in handlers}
existing = [
    h for h in plist.get("LSHandlers", [])
    if (h.get("LSHandlerContentType"), h.get("LSHandlerContentTag")) not in keys
]
for handler in handlers:
    handler["LSHandlerRoleAll"] = bundle_id
    handler["LSHandlerPreferredVersions"] = {"LSHandlerRoleAll": "-"}

plist["LSHandlers"] = existing + handlers
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "wb") as f:
    plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
EOF

  # Restart the user's LaunchServices daemon so it reloads the handlers.
  local lsd_pid
  lsd_pid="$(pgrep -u "${USER}" -x lsd || true)"
  if [[ -n "${lsd_pid}" ]]; then
    kill "${lsd_pid}"
    # Wait for launchd to respawn it, duti calls fail silently until then.
    for _ in {1..20}; do
      duti -d public.plain-text > /dev/null 2>&1 && break
      sleep 0.5
    done
    sleep 1
  fi
  # The restart drops registrations that were not flushed yet.
  "${LSREGISTER}" -f -R "${EDITOR_APP}"

  # Extensions with a type declared by another app (e.g. .toml, .log) need the
  # handler set on that type, which duti resolves.
  local target
  for target in "${targets[@]}"; do
    duti -s "${EDITOR_APP_ID}" "${target}" all 2> /dev/null || true
  done
}

_main() {
  find "$HOME/.gnupg" -type d -exec chmod 700 {} +
  find "$HOME/.gnupg" -type f -exec chmod 600 {} +

  _macos_apps
  _macos_customizations
  _macos_editor_app
  _macos_default_apps

  xargs -n1 code --install-extension < "$HOME/.vscode/extensions/list"

}

_main
