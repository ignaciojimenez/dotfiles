#!/bin/sh
# Shell-agnostic profile for both interactive and non-interactive sessions

# Core PATH settings
export PATH="/usr/local/opt/openjdk/bin:/usr/local/sbin:/Users/choco/Library/Python/3.11/bin:$PATH"

# Windsurf PATH
export PATH="/Users/choco/.codeium/windsurf/bin:$PATH"

export EDITOR='vim'

# Load core environment variables that should be available in all contexts
source ~/.exports

# Load common functions needed for non-interactive scripts
source ~/.common_functions
