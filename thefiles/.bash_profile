#!/bin/bash

# Load core profile settings
source ~/.profile

# Load bash-specific settings for non-interactive sessions here
# Currently none needed

# For interactive sessions, load additional resources
if [[ -n $PS1 ]]; then
    # exporting some env variables
    source ~/.exports
    
    # common bash functions used in scripts
    source ~/.common_functions
    
    # importing aliases
    source ~/.aliases $(detect_os)
fi
