#!/bin/bash

# Load core profile settings
source ~/.profile

# Load bash-specific options
source ~/.bash_options

# For interactive sessions, load additional resources
if [[ -n $PS1 ]]; then
    # Load aliases only in interactive sessions
    source ~/.aliases $(detect_os)
fi
