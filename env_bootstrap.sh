#!/bin/zsh

programname=$0

###  Supporting functions
## COMMON
function usage() {
  echo "usage: $programname macos|unix"
  echo "  macos|unix     description of the environment to be installed (currently only macos and unix)"
  exit 1
}

function create_ssh_key() {
  echo "------------------------------------------------------"
  echo "Creating SSH key pair"
  echo "------------------------------------------------------"
  # creating the ssh key
  mkdir ~/.ssh
  chmod 700 ~/.ssh/
  rndpwd=$(openssl rand -base64 45)
  echo "${rndpwd}" >~/.ssh/pwd
  chmod 600 ~/.ssh/pwd
  echo "*** WARNING, ssh passphrase left in cleartext in file, store and remove immediatly"
  ssh-keygen -o -a 250 -t ed25519 -f ~/.ssh/id_ed25519 -C "${USER}@${HOSTNAME}" -q -N "${rndpwd}"
}

## MACOS SPECIFIC
function install_homebrew() {
  which brew 1>&/dev/null
  if [ ! "$?" -eq 0 ]; then
    echo "Homebrew not installed. Attempting to install Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    if [ ! "$?" -eq 0 ]; then
      echo "Something went wrong. Exiting..." && exit 1
    fi
  fi
  # adding to crontab a script to auto upgrade homebrew
  echo "$(
    echo "0 1 * * * source /Users/${USER}/.scripts/brew_maintain"
    sudo crontab -u "${USER}" -l
  )" | sudo crontab -u "${USER}" -
}
function install_homebrew_apps() {
  cat <<-EndOfMessage
    Note that there are packages that need to be manually installed outside homebrew
    Packages not nicely working via homebrew
    1. Objective see packages:
      Lulu - Outbound firewall
      Block block - Blocking software installing persistent daemons
      ReiKey - Monitors keyloggers
      Knock Knock - Can check persistent installed software
    2. Others
      darktable
		EndOfMessage

  # Install packages via Homebrew
  brew cask install iterm2
  brew cask install gpg-suite
  brew cask install iina  # minimal video and music player
  brew cask install clipy  # nice clipboard management
}
function deploy_macos_usability_settings() {

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
  # Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

  # Remove the auto-hiding Dock delay
  defaults write com.apple.dock autohide-delay -float 0
  # Remove the animation when hiding/showing the Dock
  defaults write com.apple.dock autohide-time-modifier -float 0

  # Expand save panel by default
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

  # Save to disk (not to iCloud) by default
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

  # Reveal IP address, hostname, OS version, etc. when clicking the clock
  # in the login window
  # sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

  # Disable automatic capitalization as it’s annoying when typing code
  defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  # Disable smart dashes as they’re annoying when typing code
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  # Disable automatic period substitution as it’s annoying when typing code
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  # Disable smart quotes as they’re annoying when typing code
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  # Disable auto-correct
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

  # Trackpad: enable tap to click for this user and for the login screen
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  # Trackpad: map bottom right corner to right-click
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
  defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
  defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true
  # Increase sound quality for Bluetooth headphones/headsets
  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

  # Enable subpixel font rendering on non-Apple LCDs
  # Reference: https://github.com/kevinSuttle/macOS-Defaults/issues/17#issuecomment-266633501
  defaults write NSGlobalDomain AppleFontSmoothing -int 1

  # Show icons for hard drives, servers, and removable media on the desktop
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

  # Automatically hide and show the Dock
  defaults write com.apple.dock autohide -bool true
  # Make Dock icons of hidden applications translucent
  defaults write com.apple.dock showhidden -bool true
  # Don’t show recent applications in Dock
  defaults write com.apple.dock show-recents -bool false

  # Hot corners
  # Possible values:
  #  0: no-op
  #  2: Mission Control
  #  3: Show application windows
  #  4: Desktop
  #  5: Start screen saver
  #  6: Disable screen saver
  #  7: Dashboard
  # 10: Put display to sleep
  # 11: Launchpad
  # 12: Notification Center
  # 13: Lock Screen
  # Top left screen corner → Lock Screen
  defaults write com.apple.dock wvous-tl-corner -int 13
  defaults write com.apple.dock wvous-tl-modifier -int 0
  # Top right screen corner → Show Desktop
  defaults write com.apple.dock wvous-tr-corner -int 4
  defaults write com.apple.dock wvous-tr-modifier -int 0

  # Prevent Photos from opening automatically when devices are plugged in
  defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

}
function deploy_macos_security_settings() {
  # Require password immediately after sleep or screen saver begins
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  # Privacy: don’t send safari search queries to Apple
  defaults write com.apple.Safari UniversalSearchEnabled -bool false
  defaults write com.apple.Safari SuppressSearchSuggestions -bool true
  # Prevent Safari from opening ‘safe’ files automatically after downloading
  defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

  # Appstore updates
  # Enable Debug Menu in the Mac App Store
  defaults write com.apple.appstore ShowDebugMenu -bool true
  # Enable the automatic update check
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
  # Check for software updates daily, not just once per week
  defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
  # Download newly available updates in background
  defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
  # Install System data files & security updates
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
  # Turn on app auto-update
  defaults write com.apple.commerce AutoUpdate -bool true
}

# ------------------------------------------------
### ENVIRONMENT-SPECIFIC FUNCTIONS
function unix() {
  :
  # Nothing so far
}

function common() {
  :
  # TODO evaluate ssh key creation
  # create_ssh_key
  # Nothing so far
}

function macos() {
  # installing homebrew
  install_homebrew

  # installing homebew managed apps
  install_homebrew_apps

  # deploy security settigns
  deploy_macos_security_settings

  # deploy usability settings
  deploy_macos_usability_settings

  # This will only work for /bin/zsh scripts
  # ZSH confs
  # configuring ZHS command completion
  autoload -U compinit
  compinit
  # configuring vi mode for command line editing
  bindkey -v
}

### MAIN
# detecting command line input
case "$1" in
"macos")
  echo "Setting up macos and common environment"
  common
  macos
  ;;
"unix")
  echo "Setting up unix and common environment"
  common
  unix
  ;;
*)
  echo "Invalid or missing argument"
  usage
  exit 1
  ;;
esac
