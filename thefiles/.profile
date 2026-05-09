#!/bin/sh
# Shell-agnostic profile for both interactive and non-interactive sessions

# Core PATH settings
# (Library/Python/3.11/bin is the user-base bin for Apple's Python 3.11; it's
# fine if the directory doesn't exist — entries are resolved lazily.)
export PATH="/usr/local/opt/openjdk/bin:/usr/local/sbin:$HOME/Library/Python/3.11/bin:$HOME/.local/bin:$PATH"

# Windsurf PATH
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

export EDITOR='vim'

# Load core environment variables that should be available in all contexts
source ~/.exports

# Load common functions needed for non-interactive scripts
source ~/.common_functions

# Sentinel so .zshrc / .bashrc can detect that .profile already ran in a
# login shell and avoid double-sourcing.
export DOTFILES_PROFILE_LOADED=1
