# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal macOS/unix dotfiles. `bootstrap.sh` symlinks selected files from `thefiles/` into `$HOME`; `env_bootstrap.sh` (sourced via `bootstrap.sh -k`) installs Homebrew, casks, and applies macOS `defaults`. There is no build, no package manager, no CI — changes are validated by re-running `bootstrap.sh` and reloading the shell.

## Common commands

```bash
./bootstrap.sh --dry-run           # Preview symlink actions without changes
./bootstrap.sh                     # Create/refresh symlinks in $HOME
./bootstrap.sh --force             # Overwrite existing differing files (originals moved to ~/.dotfiles_backup/<timestamp>/)
./bootstrap.sh --kickstart         # Also source env_bootstrap.sh for the detected OS (Homebrew install, macOS defaults, etc.)

# Reload the shell after editing dotfiles
exec $SHELL -l                     # Or: `reload` (alias defined in .aliases)

# Ansible preauth tests (the only tests in the repo)
./thefiles/.scripts/test_ansible_preauth_unit.sh             # Baseline (passing) unit tests
./thefiles/.scripts/test_ansible_preauth_unit.sh --full      # Include currently-failing tests
./thefiles/.scripts/test_ansible_integration.sh              # Integration tests against real ansible/ansible-playbook
```

## Architecture

### Shell load order (matters when adding new settings)

The split between login vs interactive and shell-agnostic vs shell-specific is intentional — putting things in the wrong file causes them to silently not load in some contexts.

- `.profile` — shell-agnostic, sourced by both bash and zsh login shells. Owns `PATH`, `EDITOR`, and sources `.exports` + `.common_functions`. Anything that must be available to non-interactive scripts (cron, ssh commands) goes here.
- `.zprofile` / `.bash_profile` — login shell, shell-specific. Each sources `.profile` first, then adds shell-specific login-time setup.
- `.zshrc` / `.bash_options` — interactive only. Sources `.security`, then shell-specific options/keybindings, then `.aliases $(detect_os)`.
- `.aliases` is an OS-aware script: `common()` always runs, then `macos()` or `unix()` is dispatched on `$1`. When adding aliases, place them in the correct function.

### Bootstrap mechanics

- `bootstrap.sh` does NOT symlink every file in `thefiles/`. The whitelist lives in `get_shell_files()` and is shell-specific. **A new dotfile in `thefiles/` will not be linked unless added there.** Notably, `.ansible_preauth` and `.gitconfig` are NOT in the whitelist — `.ansible_preauth` is sourced via an absolute path inside `.zshrc`, and `.gitconfig` lives at `~/.gitconfig` independently.
- `detect_os()` is defined in `.common_functions` and is sourced early in `bootstrap.sh` so it's available before any symlinks exist.
- `bootstrap.sh` is idempotent: `files_differ()` compares symlink targets and skips files already pointing to the right place. Backups are only created the first time a real conflict is hit in a given run.
- `bootstrap.sh` also creates `$HOME/Workspaces -> $HOME/Documents/Workspaces` if that directory exists. This symlink is unconditional (no diff check) and will fail noisily on a second run if it already exists — use `--dry-run` first if unsure.
- `env_bootstrap.sh` is `#!/bin/zsh` and is **sourced**, not executed, by `bootstrap.sh -k`. It takes a single positional arg (`macos` or `unix`) which `bootstrap.sh` passes from `detect_os()`.

### SSH agent and git signing

`.security` selects `SSH_AUTH_SOCK` in priority order: touchid-agent → Secretive → `~/.ssh/agent.sock`. `.gitconfig` signs commits with SSH format using a touchid-agent key (`~/.ssh/touchid-agent-git.pub`) and verifies via `~/.ssh/allowed_signers`. The host's touchid-agent is configured for no-touch git signing, so unattended commits work; if signing breaks, fall back to `--no-gpg-sign` rather than blocking work.

### Ansible preauth wrapper

`thefiles/.ansible_preauth` defines bash functions that shadow `ansible` and `ansible-playbook` to handle TouchID/Secretive prompts before fanning out to multiple hosts. It is hard-sourced from `.zshrc` via absolute path and also re-sourced defensively from `.aliases`. The two test scripts in `thefiles/.scripts/` are the only test coverage in the repo and source the file directly — they expect the wrapper functions to be defined after sourcing.
