# dotfiles

Personal zsh + macOS environment. Linux-secondary, security-first.

[![lint](https://github.com/ignaciojimenez/dotfiles/actions/workflows/lint.yml/badge.svg)](https://github.com/ignaciojimenez/dotfiles/actions/workflows/lint.yml)

## Quick start

```bash
git clone https://github.com/ignaciojimenez/dotfiles.git
cd dotfiles
./bootstrap.sh --kickstart    # macOS: Homebrew + Brewfile + defaults + symlinks
                              # Linux: symlinks only (by design)
```

Re-run `./bootstrap.sh` (no `-k`) to refresh symlinks. `--dry-run` previews,
`--force` overwrites existing files (originals backed up to
`~/.dotfiles_backup/<timestamp>/`).

## What you get

- **zsh config** (`thefiles/.zshrc`, `.zsh_options`, `.zsh_keys`) — history, completion,
  emacs keybindings, modern CLI baseline (Starship, fzf, zoxide, direnv, eza, bat) —
  every tool init guarded with `command -v`, so missing tools degrade silently.
- **Security posture** (`thefiles/.security`) — touchid-agent → Secretive → gpg-agent
  agent priority, Keychain-backed Ansible vault password, signed commits via SSH-format
  Secure-Enclave key.
- **Ansible SSH preauth** (`thefiles/.ansible_preauth`) — sequential ControlMaster warmup
  before ansible runs, so parallel forks multiplex through warm sessions instead of
  triggering concurrent TouchID prompts. Delegates host enumeration to
  `ansible --list-hosts`.
- **Declarative package install** (`thefiles/Brewfile`) — `brew bundle` over scripted
  `brew install`. Idempotent.

## Layout

```
.
├── bootstrap.sh             symlink dotfiles into $HOME (idempotent, --dry-run, --force)
├── env_bootstrap.sh         OS-specific provisioning sourced by bootstrap.sh -k
├── thefiles/                everything that gets symlinked
│   ├── Brewfile             declarative brew bundle
│   ├── .ansible_preauth     SSH ControlMaster pre-warmup wrapper
│   ├── .security            SSH agent + ansible vault config
│   └── .scripts/            user-bin scripts (brew_maintain, ansible-vault-pass)
├── scripts/validate.sh      sandboxed harness — bash/zsh syntax + shellcheck +
│                            sandboxed shell load + bootstrap dry-run + Brewfile parse
├── .github/workflows/       CI: shellcheck + bash/zsh -n + brew bundle + bootstrap dry-run
└── docs/
    ├── decisions.md         one-liner architecture decisions log
    ├── improvement-plan.md  2026-05 overhaul (history)
    └── TODO.md              open polish items
```

## Linux

Linux is a real-but-secondary target — ssh into a server, want personal configs.
`bootstrap.sh` symlinks the dotfiles; `env_bootstrap.sh unix()` deliberately does
*not* install packages (distros vary, you usually want minimum footprint). The
modern CLI baseline activates as soon as you `apt`/`dnf` the tools you want.

## Validation

```bash
./scripts/validate.sh        # 21 checks, zero side effects on your environment
```

## Documentation

- [`docs/decisions.md`](docs/decisions.md) — architectural calls
- [`docs/improvement-plan.md`](docs/improvement-plan.md) — 2026-05 overhaul history
- [`docs/TODO.md`](docs/TODO.md) — open polish items
