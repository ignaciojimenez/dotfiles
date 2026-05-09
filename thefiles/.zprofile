#!/bin/zsh

# Load core profile settings (includes exports and common functions)
source ~/.profile

# Load zsh-specific settings for non-interactive sessions here
# Currently none needed

# MacPorts PATH (added by MacPorts installer 2025-11-08; kept manually).
# Skip on non-macOS — MacPorts is macOS-only.
[[ -d /opt/local/bin ]] && export PATH="/opt/local/bin:/opt/local/sbin:$PATH"

