# Set default working directory
export WORKSPACE_DIR="$HOME/Documents/Workspaces"
[[ -d "$WORKSPACE_DIR" ]] && cd "$WORKSPACE_DIR"

# Load security settings
source ~/.security

# Load ZSH-specific options and key bindings
source ~/.zsh_options
source ~/.zsh_keys

# Load interactive shell customizations
source ~/.aliases $(detect_os)
