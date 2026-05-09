#!/bin/bash
# Environment bootstrap — sourced by bootstrap.sh -k.
# Usage: source env_bootstrap.sh <macos|unix>
#
# macos: Homebrew + Brewfile + macOS defaults + scheduled brew_maintain
# unix:  no-op for now (step 3 of docs/improvement-plan.md will fill this in
#        with a Linux-on-zsh experience: gpg-agent socket, Linux package install)

programname=$0

# ─── Shared helpers ──────────────────────────────────────────────────────────

usage() {
  echo "usage: $programname macos|unix" >&2
  echo "  macos|unix  environment to provision" >&2
  exit 1
}

# ─── macOS-specific ──────────────────────────────────────────────────────────

install_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || { echo "Homebrew install failed" >&2; return 1; }
  else
    echo "==> Homebrew already installed"
  fi

  # Idempotent crontab entry for daily brew maintenance. No `source`
  # (cron's /bin/sh doesn't have it), no `sudo` (the user's own crontab),
  # and any existing brew_maintain line is replaced.
  local cron_entry="0 1 * * * \$HOME/.scripts/brew_maintain"
  ( crontab -l 2>/dev/null | grep -v 'brew_maintain' ; echo "$cron_entry" ) | crontab -
  echo "==> Scheduled $HOME/.scripts/brew_maintain at 01:00 daily"
}

install_packages() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  local brewfile="$script_dir/thefiles/Brewfile"
  if [[ ! -f "$brewfile" ]]; then
    echo "==> No Brewfile at $brewfile — skipping" >&2
    return 0
  fi
  echo "==> Installing/refreshing packages from $brewfile"
  brew bundle --file="$brewfile"
}

deploy_macos_usability_settings() {
  # Disable Notification Center and remove the menu bar icon
  launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2> /dev/null

  # Finder: show all filename extensions
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  # Finder: show path bar
  defaults write com.apple.finder ShowPathbar -bool true
  # Finder: Display full POSIX path as Finder window title
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  # Finder: Keep folders on top when sorting by name
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  # Finder: When performing a search, search the current folder by default
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
  # Finder: Avoid creating .DS_Store files on network or USB volumes
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
  # Finder: Use list view in all Finder windows by default
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

  # Remove the auto-hiding Dock delay/animation
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0

  # Expand save panel by default
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

  # Save to disk (not to iCloud) by default
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

  # Disable autocorrect annoyances when typing code
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

  # Trackpad: enable tap to click for this user and for the login screen
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  # Trackpad: bottom-right corner = right-click
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
  defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
  defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

  # Increase BT audio quality
  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

  # Subpixel font rendering on non-Apple LCDs
  defaults write NSGlobalDomain AppleFontSmoothing -int 1

  # Show drives/servers/etc. on the desktop
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

  # Dock behaviour
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock showhidden -bool true
  defaults write com.apple.dock show-recents -bool false

  # Hot corners: 13=Lock Screen, 4=Desktop
  defaults write com.apple.dock wvous-tl-corner -int 13
  defaults write com.apple.dock wvous-tl-modifier -int 0
  defaults write com.apple.dock wvous-tr-corner -int 4
  defaults write com.apple.dock wvous-tr-modifier -int 0

  # Don't open Photos when devices plug in
  defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
}

deploy_macos_security_settings() {
  # Require password immediately after sleep / screen saver
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  # Don't send Safari search queries to Apple
  defaults write com.apple.Safari UniversalSearchEnabled -bool false
  defaults write com.apple.Safari SuppressSearchSuggestions -bool true
  defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

  # App Store update behaviour
  defaults write com.apple.appstore ShowDebugMenu -bool true
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
  defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
  defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
  defaults write com.apple.commerce AutoUpdate -bool true
}

# ─── Environment dispatchers ─────────────────────────────────────────────────

macos() {
  install_homebrew
  install_packages
  deploy_macos_security_settings
  deploy_macos_usability_settings
}

unix() {
  # Linux is a secondary, occasional-use target. We deliberately do
  # *not* install packages here: server/VM contexts vary too much
  # across distros and you usually want minimal install footprint.
  # The dotfiles already symlinked into $HOME degrade gracefully —
  # every modern-CLI init in .zshrc is `command -v`-guarded, so a
  # missing tool is a no-op, not an error.
  echo "==> Linux: dotfiles symlinked. No package install (by design)."
  echo "==> If you want the modern CLI baseline on this host, install"
  echo "==> manually with the system package manager, e.g.:"
  echo "    apt install zsh fzf ripgrep fd-find bat eza zoxide direnv"
  echo "    # then add fzf integration once: \$(brew --prefix)/opt/fzf/install"
  if ! command -v zsh >/dev/null 2>&1; then
    echo "==> WARNING: zsh not found on this host. Install it before sourcing the dotfiles."
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────

case "${1:-}" in
  macos) echo "==> Setting up macOS environment"; macos ;;
  unix)  echo "==> Setting up unix environment";  unix ;;
  *)     usage ;;
esac
