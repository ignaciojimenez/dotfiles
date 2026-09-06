# In a login shell .zprofile → .profile already provides $PATH, .exports
# and detect_os. In a non-login interactive shell (e.g. inside tmux, IDE
# terminals) .zprofile is skipped, so source .profile defensively.
[[ -z "$DOTFILES_PROFILE_LOADED" && -f ~/.profile ]] && source ~/.profile

# Load security settings
source ~/.security

# Load ZSH-specific options and key bindings
source ~/.zsh_options
source ~/.zsh_keys

# Load interactive shell customizations
source ~/.aliases $(detect_os)

# Ansible SSH preauth wrapper (sourced via the symlink set up by bootstrap.sh)
[[ -f ~/.ansible_preauth ]] && source ~/.ansible_preauth

# ─── Modern CLI baseline ─────────────────────────────────────────────────────
# starship/zoxide/direnv/fzf init differs between shells only by the shell's
# name, so it lives in .shell_tools and is shared rather than duplicated.
# Each block in there is guarded on the tool's presence, so a host that hasn't
# run `brew bundle` (or a fresh Linux box) still loads cleanly.
[[ -f ~/.shell_tools ]] && source ~/.shell_tools zsh