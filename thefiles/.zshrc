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
# Each block is guarded on the tool's presence so a host that hasn't run
# `brew bundle` (or a fresh Linux box) still loads cleanly.

# Prompt
command -v starship >/dev/null && eval "$(starship init zsh)"

# Smart cd: `z <fragment>` jumps to frecent directories
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# Per-directory env vars (Cloudflare tokens, venv activation, etc.)
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# Fuzzy finder — keybindings + completion. fzf installs the init scripts at
# $(brew --prefix)/opt/fzf/shell/ on Homebrew. Source them only if present.
if command -v fzf >/dev/null; then
  __fzf_dir="$(brew --prefix 2>/dev/null)/opt/fzf/shell"
  [[ -f "$__fzf_dir/key-bindings.zsh" ]] && source "$__fzf_dir/key-bindings.zsh"
  [[ -f "$__fzf_dir/completion.zsh"   ]] && source "$__fzf_dir/completion.zsh"
  unset __fzf_dir
fi