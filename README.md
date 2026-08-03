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
  agent priority, Keychain-backed Ansible vault password, opt-in commit signing via a
  touch-required Secure-Enclave key (signature = human attestation, not noise).
- **Ansible SSH preauth** (`thefiles/.ansible_preauth`) — sequential ControlMaster warmup
  before ansible runs, so parallel forks multiplex through warm sessions instead of
  triggering concurrent TouchID prompts. Delegates host enumeration to
  `ansible --list-hosts`.
- **Declarative package install** (`thefiles/Brewfile`) — `brew bundle` over scripted
  `brew install`. Idempotent.
- **Portable AI agent context** (all platforms) — `agent-context/AGENTS.md` is one
  canonical personal-context file, symlinked into every agent harness's global
  config path by `bootstrap.sh`. Budgeted at 6,000 characters so it fits the
  strictest harness verbatim; `scripts/validate.sh` fails if it grows past that.
  See [`AGENTS.md`](AGENTS.md) for the adapter table and what's actually verified.

  Gemini CLI needs one manual step, since `~/.gemini/GEMINI.md` is left alone for
  Antigravity to own — add to `~/.gemini/settings.json`:

  ```json
  { "context": { "fileName": ["AGENTS.md", "GEMINI.md"] } }
  ```

## Layout

```
.
├── bootstrap.sh             symlink dotfiles into $HOME (idempotent, --dry-run, --force)
├── env_bootstrap.sh         OS-specific provisioning sourced by bootstrap.sh -k
├── agent-context/AGENTS.md  canonical personal context for all agent harnesses
├── .claude/CLAUDE.md        Claude Code importer: @-imports the canonical context
├── thefiles/                everything that gets symlinked
│   ├── Brewfile             declarative brew bundle
│   ├── .ansible_preauth     SSH ControlMaster pre-warmup wrapper
│   ├── .security            SSH agent + ansible vault config
│   └── .scripts/            user-bin scripts (brew_maintain, ansible-vault-pass)
├── scripts/validate.sh      sandboxed harness — bash/zsh syntax + shellcheck +
│                            sandboxed shell load + bootstrap dry-run + Brewfile parse
├── .github/workflows/       CI: shellcheck + bash/zsh -n + brew bundle + bootstrap dry-run
├── AGENTS.md                conventions / non-obvious bits for AI coding agents
└── docs/
    └── decisions.md         architectural-call log (newest first; includes known to-dos)
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

- [`docs/decisions.md`](docs/decisions.md) — architectural calls + known to-dos
- [`AGENTS.md`](AGENTS.md) — non-obvious bits for AI coding agents
