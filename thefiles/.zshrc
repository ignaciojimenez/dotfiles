# Set default working directory
#export WORKSPACE_DIR="$HOME/Documents/Workspaces"
#[[ -d "$WORKSPACE_DIR" ]] && cd "$WORKSPACE_DIR"

# Load security settings
source ~/.security

# Load ZSH-specific options and key bindings
source ~/.zsh_options
source ~/.zsh_keys

# Load interactive shell customizations
source ~/.aliases $(detect_os)

# Ansible SSH preauth wrapper (sourced via the symlink set up by bootstrap.sh)
[[ -f ~/.ansible_preauth ]] && source ~/.ansible_preauth