#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

# shellcheck source=/dev/null
source "$HOME/.config/shell/functions/logging"

# errtrace also fires the trap in subshells, only report once from the main shell.
# A failing `return` comes from a function that already logged its own error.
trap '(( BASH_SUBSHELL == 0 )) && [[ "${BASH_COMMAND}" != return* ]] && _error "Failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

readonly EDITOR_APP="$HOME/Applications/Editor.app"
readonly EDITOR_APP_ID='com.github.j-martin.editor'
readonly LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'

# Lives in /var/run, which macOS wipes at boot, so password auth never survives a reboot.
# Must match the `Include` in ~/.setup/sshd_config.
readonly SSH_PASSWORD_CONF='/var/run/sshd-allow-password-temporarily.conf'
readonly SSH_KEYS_ONLY_CONF='/etc/ssh/sshd_config.d/000-keys-only.conf'

# ~/.claude/settings.json is untracked: it holds machine-specific hooks and private work context.
readonly CLAUDE_SETTINGS="$HOME/.claude/settings.json"
readonly CLAUDE_ALLOWED_TOOLS=(
  'Bash(hc wait:*)'
  'Bash(hc read:*)'
  'Bash(hc ls:*)'
  'Bash(hc get:*)'
)

_macos_customizations() {
  _info 'Applying macOS customizations.'
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

  _info 'Restarting Dock and Finder.'
  killall Dock || true
  killall Finder || true
}

_macos_apps() {
  _info 'Installing Xcode command line tools.'
  xcode-select --install || true
  _info 'Installing Homebrew.'
  NONINTERACTIVE=1 /bin/bash -c "$(curl --fail --silent --show-error --location https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  _info 'Installing mise and its packages.'
  curl --fail --silent --show-error --location https://mise.run | sh
  "$HOME/.local/bin/mise" bootstrap packages apply
  "$HOME/.local/bin/mise" install
  # mise cannot evaluate emacs-plus: the formula requires sibling files from its tap.
  _info 'Installing emacs-plus.'
  /opt/homebrew/bin/brew install d12frosted/emacs-plus/emacs-plus@31

  # The rest of the setup needs the freshly installed tools (npm, code, ...)
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

  _info 'Registering zsh as a login shell.'
  which zsh \
    | head -n1 \
    | sudo tee -a /etc/shells
}

# Editor.app forwards double-clicked files to ~/.bin/editor, which opens them in
# Emacs (emacsclient) or runs them when they are executable.
_macos_editor_app() {
  local app="${EDITOR_APP}"
  _info "Building '${app}'."
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

  _info 'Setting Editor.app as the default app for text files.'
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

# Adds `CLAUDE_ALLOWED_TOOLS` to the Claude Code permission allow list, keeping existing entries.
_claude_permissions() {
  local settings="${CLAUDE_SETTINGS}"
  _info "Adding Claude Code permissions to '${settings}'."
  mkdir -p "$(dirname "${settings}")"
  if [[ ! -s "${settings}" ]]; then
    printf '{}\n' > "${settings}"
  fi
  local allowed
  allowed="$(printf '%s\n' "${CLAUDE_ALLOWED_TOOLS[@]}" | jq --raw-input --slurp 'split("\n") | map(select(length > 0))')"
  local updated
  updated="$(jq --argjson allowed "${allowed}" \
    '.permissions.allow = ((.permissions.allow // []) as $existing | $existing + ($allowed - $existing))' "${settings}")"
  printf '%s\n' "${updated}" > "${settings}"
}

# Restricts sshd to ssh-key auth and removes any temporary password override.
_ssh_keys_only() {
  _info "Installing '${SSH_KEYS_ONLY_CONF}'."
  sudo rm -f "${SSH_PASSWORD_CONF}"
  sudo install -m 0644 "$HOME/.setup/sshd_config" "${SSH_KEYS_ONLY_CONF}"
  sudo sshd -t || return 1
  _info "Password auth disabled, ssh-key only. Run '~/.setup/setup.sh _ssh_allow_password [minutes]' to allow it temporarily."
}

# Temporarily allows ssh password auth for the given minutes (default 10) or until Enter/Ctrl-C.
_ssh_allow_password() {
  local minutes="${1:-10}"
  (
    sudo --validate || exit 1
    # Refreshes the sudo timestamp so the revert does not prompt after the timeout.
    local parent="${BASHPID}"
    while kill -0 "${parent}" 2> /dev/null && sudo --non-interactive --validate 2> /dev/null; do
      sleep 60
    done &
    local keepalive=$!
    _ssh_keys_only || exit 1
    trap '_ssh_keys_only; kill "${keepalive}" 2> /dev/null' EXIT
    trap 'exit 130' INT TERM HUP
    printf '%s\n' \
      'PasswordAuthentication yes' \
      'KbdInteractiveAuthentication yes' \
      'AuthenticationMethods any' \
      | sudo tee "${SSH_PASSWORD_CONF}" > /dev/null
    sudo sshd -t || exit 1
    _warn "Password auth enabled for ${minutes} min. Press Enter or Ctrl-C to revert."
    read -r -t "$((minutes * 60))" || true
  )
}

# Asks the running sshd which auth methods it offers and reports whether passwords are accepted.
_ssh_status() {
  local output methods
  output=$(ssh -F /dev/null -o BatchMode=yes -o PubkeyAuthentication=no \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR -o ConnectTimeout=5 localhost true 2>&1) || true
  methods=$(sed -n 's/.*Permission denied (\(.*\))\./\1/p' <<< "${output}")
  if [[ -z "${methods}" ]]; then
    _error "Could not read the sshd auth methods, is Remote Login on? ${output}"
    return 1
  fi
  if [[ ",${methods}," == *,password,* || ",${methods}," == *,keyboard-interactive,* ]]; then
    _warn "Password auth is ALLOWED, sshd offers: ${methods}."
  else
    _info "Password auth is rejected, sshd offers: ${methods}."
  fi
}

_main() {
  _info 'Fixing ~/.gnupg permissions.'
  find "$HOME/.gnupg" -type d -exec chmod 700 {} +
  find "$HOME/.gnupg" -type f -exec chmod 600 {} +

  _macos_apps
  _macos_customizations
  _macos_editor_app
  _macos_default_apps
  _ssh_keys_only
  _claude_permissions

  _info 'Installing VS Code extensions.'
  xargs -n1 code --install-extension < "$HOME/.vscode/extensions/list"
}

# Runs `_main`, or the given function (e.g. `setup.sh _ssh_keys_only`) with the remaining arguments.
_run() {
  local function_name="${1:-_main}"
  if ! declare -F "${function_name}" > /dev/null; then
    _error "Unknown function '${function_name}'."
    exit 1
  fi
  shift || true
  _info "Running '${function_name}'."
  "${function_name}" "$@"
  _info "Done '${function_name}'."
}

_run "$@"
