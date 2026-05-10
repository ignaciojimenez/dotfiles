# AGENTS.md

Notes for AI coding agents working in this repository. Vendor-neutral
(see [agents.md](https://agents.md)).

## What this repo is

Personal zsh + macOS dotfiles, with Linux as a graceful-degradation
secondary. There is no build, no test framework — changes are validated
by `./scripts/validate.sh` (sandboxed shell load + bash/zsh syntax +
shellcheck + bootstrap dry-run + Brewfile parse) and by re-running
`bootstrap.sh`.

## Things that aren't obvious from reading individual files

### Shell load order

The split between *login vs interactive* and *shell-agnostic vs
shell-specific* is deliberate; putting things in the wrong file means
they silently won't load in some contexts.

- `.profile` — shell-agnostic, sourced by every login shell. Owns
  `PATH`, `EDITOR`, `STARSHIP_CONFIG`, sources `.exports` +
  `.common_functions`. Anything that must be available to non-interactive
  scripts (cron, ssh commands) goes here.
- `.zprofile` — login zsh only. Sources `.profile` first, then
  shell-specific login-time setup.
- `.zshrc` — interactive zsh only. Sources `.security`, `.zsh_options`,
  `.zsh_keys`, then `.aliases $(detect_os)`, then the modern-CLI inits
  (starship/zoxide/direnv/fzf), each `command -v`-guarded.
- `.aliases` is OS-aware: `common()` always runs, `macos()` is
  dispatched on `$1`. Place new aliases in the right block.

### Bootstrap symlink whitelist

`bootstrap.sh::get_dotfiles` lists exactly which files in `thefiles/`
get symlinked into `$HOME`. **A new dotfile in `thefiles/` will not
be linked unless it's added there.** Notably: `.gitconfig`,
`.ansible_preauth`, `.starship.toml` are all in the whitelist.

### Linux fallback

`bootstrap.sh` symlinks the same dotfiles on Linux but
`env_bootstrap.sh unix()` is intentionally a no-op (no package
install). Modern-CLI tools (eza/bat/rg/fd/fzf/zoxide/starship)
activate via the `command -v` guards in `.zshrc` once the user
installs them through the system package manager.

## Common commands

```bash
./bootstrap.sh --dry-run       # preview symlink actions
./bootstrap.sh                 # refresh symlinks
./bootstrap.sh --kickstart     # also source env_bootstrap.sh
                               # (macOS: brew + Brewfile + defaults; Linux: no-op)

./scripts/validate.sh          # full local validation, no side effects
./scripts/validate.sh --quick  # skip Brewfile check

brew bundle --file=thefiles/Brewfile   # install/refresh packages
```

## Conventions

- All commits signed (`-S`) via touchid-agent's no-touch git key. If
  the agent is unreachable: `--no-gpg-sign` is the documented
  fallback, not a workaround to skip silently.
- `docs/decisions.md` is the architectural-call log — add entries
  newest-first when making non-obvious choices.
