# Decisions

One-liner record of architecture/strategy calls. Newest first.

## 2026-05-09

- **zsh-only.** Bash dropped from the dotfiles. Shell selection multiplexing was speculative and never exercised; collapsing to one shell removes ~40% of branching code.
- **Linux is a graceful-degradation secondary.** `bootstrap.sh` symlinks the dotfiles on any host; `env_bootstrap.sh unix()` deliberately does *not* install packages. Linux server use is occasional ("ssh in, want my shell"), distro variance is high, and every modern-CLI init in `.zshrc` is `command -v`-guarded so missing tools degrade silently.
- **Ansible wrapper delegates host enumeration to Ansible itself** (`ansible[-playbook] --list-hosts`). Reimplementing argv parsing, group resolution, and inventory parsing in bash was the source of every bug in the prior 326-line wrapper; the delegated list is by definition consistent with the run that follows.
- **Brewfile + `brew bundle` over scripted `brew install`.** Idempotent, declarative, and reviewable as a diff. `brew cask install` (the previous approach) is deprecated since 2020 anyway.
- **touchid-agent is the primary SSH agent.** Secure Enclave-backed, no-touch git signing for unattended commits, falls through to Secretive (macOS) → gpg-agent (Linux) → generic `~/.ssh/agent.sock`. Matches the security-first posture without compromising ergonomics.
