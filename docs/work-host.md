# Work host

Running these dotfiles on an employer-managed Mac: what the `work` profile
changes, how to set it up, and the checks still owed on a real work laptop.

## What the profile changes

`./bootstrap.sh --profile work` saves the profile to
`~/.config/dotfiles/profile`, so a plain re-run stays `work`.

| | personal | work |
|---|---|---|
| Shell dotfiles, agent-context adapters (incl. Droid), agent-sessions plugin | linked | linked |
| `~/.claude/settings.json` → `harness/claude/settings.json` | linked | **not linked** — its auto-mode rules describe the personal estate |
| Git identity | `.gitconfig.personal` | **must** be set in `~/.gitconfig.local`, or bootstrap fails |
| `--kickstart`: `Brewfile` | installed | installed |
| `--kickstart`: `Brewfile.personal` (custom tap, casks, `openssh`, Ansible, network tools) | installed | **skipped** |
| `--kickstart`: Notification Center unload | yes | **skipped** — device-management prompts arrive through it |

The agent context is the same file everywhere. Its *Personal projects only*
section is scoped to repos under `github.com/ignaciojimenez`, and its first
rule is that a repo's own conventions win.

**Git identity is layered** (`thefiles/.gitconfig`): personal default, then
the untracked `~/.gitconfig.local`, then personal again for any repo with a
remote under `github.com/ignaciojimenez`. So on a work laptop, work repos get
the work email, and a clone of this repo still commits as personal. Verified
in a scratch `$HOME` with real commits, over SSH and HTTPS remotes, with a
lookalike owner (`ignaciojimenez-evil`) correctly *not* matched.

## Setup

```bash
git clone https://github.com/ignaciojimenez/dotfiles.git && cd dotfiles
git switch feat/work-profile                      # until it is merged
[ -f ~/.gitconfig ] && mv ~/.gitconfig ~/.gitconfig.local   # IT's settings become the host layer
git config --file ~/.gitconfig.local user.email <you@company>
./bootstrap.sh --dry-run --profile work           # read it before running it
./bootstrap.sh --profile work
./scripts/validate.sh
./bootstrap.sh --kickstart                        # optional; Homebrew formulae only
```

## Validation brief — for an agent on the work laptop

Verified so far only on the personal Mac and in scratch `$HOME`s. Each check
below needs the real machine. Report per check: the command, its output, and
pass / fail / unclear.

**The repo is public.** Put findings in the session or a local untracked
file, not in a commit: hostnames, internal tool names and IT policy details
must not reach this repo. Ignacio moves what is safe to publish.

1. **Bootstrap and validate.** Setup above runs clean; `./scripts/validate.sh`
   has no failures.
2. **Droid loads the global context.** In a repo with no `AGENTS.md`, ask what
   the *Personal projects only* section says about the task queue — it can
   only answer if `~/.factory/AGENTS.md` was loaded. Repeat in a repo that has
   its own `AGENTS.md`. Establish whether Droid *also* reads
   `~/.claude/CLAUDE.md` (the same file, twice) or `~/.agents/`.
3. **Scoping holds.** In a work repo, ask which task queue and deploy stack
   apply: expected answer is the repo's own, never Linear `PER` or
   Cloudflare. In this repo, expected answer is Linear `PER`.
4. **Git identity.** `git config --show-origin user.email` in a work repo and
   in this clone. `git config --show-origin --get-all credential.helper` still
   shows IT's helper, if it shipped one.
5. **Shell noise.** `zsh -i -c exit` and `zsh -l -c exit` print nothing to
   stderr.
6. **SSH agent.** `echo $SSH_AUTH_SOCK` in a new shell: is it the agent IT
   configured? `thefiles/.security` overrides it if touchid-agent, Secretive
   or a gpg agent socket exists.
7. **Interference with company tooling.** `umask 077` (`.security`): does
   anything need group-readable files? `type python`: the `python` function
   in `.aliases` runs `/usr/bin/python3` outside a virtualenv — does that
   shadow the company's pyenv/uv setup?
8. **Homebrew.** Every formula in `thefiles/Brewfile` installs under company
   policy (`brew bundle check --file=thefiles/Brewfile`). Endpoint security
   raises no alert — ask IT; an agent cannot see this.
9. **Kickstart side effects.** Which `defaults write` keys device management
   overrides (`defaults read` a few afterwards). Whether the nightly
   `brew_maintain` crontab (`brew upgrade` of everything, cache wipe) is
   acceptable on a managed machine — it is not profile-gated yet.
10. **Droid hooks.** Whether `~/.factory/hooks.json` `SessionStart` /
    `SessionEnd` payloads carry what `agent-sessions` needs, and what the
    resume command is — the input for a `droid` adapter. Recommend; don't
    build.
