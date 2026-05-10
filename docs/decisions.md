# Decisions

One-liner record of architecture/strategy calls. Newest first.

## 2026-05-10

- **Commit signing is opt-in attestation, not a default.** `commit.gpgSign=false` globally; signing key is a separate touch-required Secure-Enclave key (`touchid-agent-sign`). Rationale: a signature on every WIP commit produced by an unattended no-touch key proves only "key X is loaded on this machine" — the same guarantee SSH auth gives. The thing that makes a signature meaningful (vs. just a fancy auth token) is human presence; auto-signing discards exactly that property. Aliases (`git cs` / `git ms` / `git ts`) make deliberate signing one-keystroke. Supersedes the "no-touch git-signing key for unattended commits" half of the 2026-05-09 touchid-agent decision; SSH-auth-via-touchid-agent stands.

## 2026-05-09

- **zsh-only.** Bash dropped. Shell-selection multiplexing was speculative and never exercised; collapsing to one shell removes ~40% of branching code.
- **Linux is a graceful-degradation secondary.** `bootstrap.sh` symlinks the dotfiles on any host; `env_bootstrap.sh unix()` deliberately does *not* install packages. Linux server use is occasional ("ssh in, want my shell"); distro variance is high; every modern-CLI init in `.zshrc` is `command -v`-guarded so missing tools degrade silently.
- **Ansible wrapper delegates host enumeration to Ansible itself** (`ansible[-playbook] --list-hosts`). Reimplementing argv parsing, group resolution, and inventory parsing in bash was the source of every bug in the prior 326-line wrapper; the delegated list is by definition consistent with the run that follows.
- **Brewfile + `brew bundle` over scripted `brew install`.** Idempotent, declarative, reviewable as a diff. `brew cask install` (the prior approach) was deprecated in 2020.
- **wrangler stays on npm, not Homebrew.** `npm i -g wrangler` is what Cloudflare publishes first; the brew formula conflicted with the existing npm symlink at `/usr/local/bin/wrangler`. Keep one.
- **touchid-agent is the primary SSH agent.** Secure Enclave-backed, no-touch git-signing key for unattended commits, falls through to Secretive (macOS) → gpg-agent (Linux) → generic `~/.ssh/agent.sock`.
- **Subdued prompt and `ls` palette.** Cyan accent on path + muted gray everything else (starship); file-type colors only on eza, no per-file icons or git-status indicators. Information density preserved, color noise removed.

## Known to-dos

Cosmetic/stylistic. None blocking, none insecure.

- `setopt CORRECT` / `CORRECT_ALL` in `.zsh_options` — drop unless you actually use the "did you mean…" prompt.
- `export TERM=xterm-256color` in `.zsh_keys` — wrong file (it's an env var) and overrides what the terminal advertises. Move to `.exports` or delete.
- Custom `python()` in `.aliases` macos block — overrides pyenv shims to fall back to `/usr/bin/python3`. Decide which one is authoritative and drop the other.
- `lwp-request`-based `GET`/`POST`/… aliases in `.aliases` — replace with `httpie` or just remove.
- `EDITOR='vim'` set in `.profile` but no `.vimrc` tracked. Commit one or switch editor.
- `brew bundle cleanup --file=thefiles/Brewfile --dry-run` periodically to reconcile drift.
