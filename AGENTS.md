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

Some symlinks are handled *outside* `get_dotfiles`, in dedicated blocks at
the end of `create_symlinks` (they aren't flat dotfiles in `thefiles/`).
`~/Workspaces -> ~/Documents/Workspaces` is macOS-only. The AI-context
wiring runs on **every** platform, because Linux agent hosts are the whole
point of it — see `docs/decisions.md` (2026-08-04).

### AI agent context

`agent-context/AGENTS.md` is the canonical personal context for every agent
harness — tracked here, budgeted at 6,000 characters, enforced by
`scripts/validate.sh`. Don't confuse it with *this* file, which is
repo-scoped guidance about the dotfiles repo itself.

`bootstrap.sh` links `~/.agent-context -> agent-context/`, then points each
harness's global-config path at it. Everything routes through that one
indirection, so no username or clone location is ever hardcoded:

| Path | Harness | Status |
|---|---|---|
| `~/.claude/CLAUDE.md` → `.claude/CLAUDE.md` | Claude Code (also read by OpenCode + Devin CLI) | **confirmed working** |
| `~/.config/opencode/AGENTS.md` | OpenCode | wired, unverified |
| `~/.config/devin/AGENTS.md` | Devin CLI | wired, unverified |
| `~/.gemini/AGENTS.md` | Gemini CLI (needs `context.fileName`, see README) | wired, unverified |
| `~/.codeium/windsurf/memories/global_rules.md` | Devin Desktop / Windsurf | wired, unverified |

"Wired, unverified" means the symlink is created but nobody has confirmed
that harness actually loads it. Say so rather than claiming coverage — the
previous version of this setup asserted five harnesses read the file when
only one did.

`~/.gemini/GEMINI.md` is **deliberately not linked**: Antigravity writes to
it, and a symlink would let it overwrite the tracked file.

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

- Signing is opt-in attestation, not a default. `commit.gpgSign=false`
  globally; the signing key is touch-required (`touchid-agent-sign`),
  so each `-S` is one TouchID prompt that means "human present, human
  approved." Sign deliberately at meaningful moments — merges to main
  (`git ms`), release tags (`git ts`) — not on every WIP commit.
- `docs/decisions.md` is the architectural-call log — add entries
  newest-first when making non-obvious choices.
