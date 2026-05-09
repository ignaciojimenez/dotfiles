# Dotfiles improvement plan

Working plan derived from the 2026-05-07 deep assessment. Self-contained — readable cold without conversation context.

## Goal

Bring the repo to "clean senior portfolio" quality:
- Bootstrap chain that reliably provisions a fresh macOS host
- Drop dead/duplicate code
- Remove hardcoded usernames and broken behaviours
- Replace the fragile `ansible_preauth` wrapper with a tiny one that delegates to Ansible itself
- Ship the modern CLI baseline (Brewfile, plugin manager, fzf/zoxide/etc.) befitting current dev practice

Constraint (refined 2026-05-09): zsh on macOS as primary, zsh on Linux as a real-but-occasional secondary. Drop bash, drop windows/freebsd, but keep cross-platform-zsh as a goal.

---

## TL;DR — execute in this order

1. **Delete `profile_bootstrap`** (broken + obsolete paradigm — see §Step 1)
2. **De-hardcode `/Users/choco`** across `.profile`, `.gitconfig`, `.zshrc`
3. **Drop bash + windows + freebsd, keep zsh-on-Linux** (reframed 2026-05-09)
4. **Replace `.ansible_preauth`** with the ~25-line delegation-to-ansible version (reassessed 2026-05-09)
5. **Fix `env_bootstrap.sh`** + add `thefiles/Brewfile`
6. **Modern CLI baseline** (mise, direnv, fzf, zoxide, eza/bat/rg/fd, plugin manager) — guarded so missing tools don't break the shell
7. **`docs/decisions.md` + shellcheck CI**

`bootstrap.sh.bak` already deleted by user (2026-05-09).

---

## Bootstrap chain — target architecture

A fresh laptop should reach a working dev environment via:

```
xcode-select --install     # manual prereq
git clone <repo>           # manual prereq
./bootstrap.sh -k          # everything else
```

`bootstrap.sh -k` does, in order:
1. Detect OS (macOS only; bail otherwise)
2. Symlink whitelisted files from `thefiles/` into `$HOME`
3. Source `env_bootstrap.sh macos`, which:
   - Installs Homebrew if missing
   - `brew bundle --file=thefiles/Brewfile` (declarative — replaces today's `brew cask install` block)
   - Applies macOS `defaults` (usability + security — already present, keep)
   - Adds `~/.scripts/brew_maintain` to crontab (idempotent, no `source`, no `sudo`)

Post-bootstrap (manual, one-time, won't automate — secrets):
- Authorize touchid-agent and create the SSH key in Secure Enclave
- `gh auth login`
- Add `ansible-vault-master` to Keychain
- Sign into 1Password / mise / etc.

---

## Bugs catalogued (for reference during execution)

### `.ansible_preauth` — root cause for "random warm-up failures"

| # | Bug | Location | Effect |
|---|---|---|---|
| A | `get_preauth_hosts "$args"` collapses all argv into one string | line 210, 223 | Playbook detection (`*.yml`) and `-i` detection silently never match. Falls back to `inventory/` cwd discovery. When that fails → "No hosts found" → no warmup. **Main cause of symptom.** |
| B | Inventory parser strips legitimate host lines containing `=` | line 146 | Hosts with `ansible_host=…` per-host vars are filtered out. Empty host list → no warmup. |
| C | `find -newer <(date ...)` always returns 0 matches | line 213-218 | Process substitution gives find a pipe whose mtime is "now"; nothing is newer. Guard is a no-op. Benign (just disables short-circuit) but the comment lies. |
| D | `local args=($*)` (unquoted) in `extract_ansible_targets` | line 270 | Word-splits + globs against cwd. Mangles quoted patterns. Source of several `FAILING_TESTS` entries. |

Reproductions verified empirically on 2026-05-07:
- A: flat-string iteration over `playbook.yml --check --limit foo` doesn't match `*.yml`
- B: `[pis]\npihole ansible_host=192.168.1.10` parses to zero hosts
- C: `find -newer <(date -v-9M …)` over `control:fresh` returns 0

### `env_bootstrap.sh`

| Location | Bug |
|---|---|
| line 29 | `which brew 1>&/dev/null` — invalid redirect syntax |
| line 38-41 | Cron line uses `source` (cron's `/bin/sh` doesn't have it); uses `sudo crontab -u $USER` (gratuitous, prompts); not idempotent (re-appends every run) |
| line 57-60 | `brew cask install X` is deprecated → errors on modern Homebrew |
| line 21-24 | `create_ssh_key` writes a generated passphrase to `~/.ssh/pwd` in cleartext (function unreachable, but bad to have in a public repo) |
| line 218-225 | `compinit`, `bindkey -v` run inside the bootstrap subshell — die on script exit |

### `bootstrap.sh`

| Location | Bug |
|---|---|
| line 97 | `grep "^${USER}:" /etc/passwd` — macOS doesn't store users in `/etc/passwd`; this branch is dead |
| line 176 | Filter for `.git`/`.gitignore`/`.DS_Store`/etc is dead code (iterating over a fixed whitelist that can't contain those) |
| line 223-232 | `~/Workspaces` symlink runs unconditionally on every invocation — fails noisily on second run |

### Hardcoded paths

- `thefiles/.profile:5,8` — `/Users/choco/Library/Python/3.11/bin`, `/Users/choco/.local/bin`, `/Users/choco/.codeium/windsurf/bin`
- `thefiles/.gitconfig:2,9` — `signingkey`, `allowedSignersFile`
- `thefiles/.zshrc:14` — absolute path to `.ansible_preauth`

### Other smells

- `.zsh_options:47-48` — `setopt CORRECT` + `CORRECT_ALL` (the "did you mean" annoyance)
- `.zsh_keys:43` — `export TERM=xterm-256color` from a keybindings file, can break SSH/tmux
- `.aliases:51-53` — conditional `source ~/.ansible_preauth` is dead (file isn't symlinked); `.zshrc` sources by absolute path instead
- `.gitignore` lists itself (harmless but odd)

---

## Steps in detail

### Step 1 — Delete `profile_bootstrap`

**Why it's not just stale:**
- Last touched Feb 2021. Never updated when `bootstrap.sh` replaced it.
- Three independent execution-blocking bugs (calls `custom_profile` with filename instead of shell name → `exit 1`; calls a *variable* as if it were a function; `writeprofile` defined but never invoked).
- **Inverted paradigm**: moves `~/.zshrc` *into* `thefiles/` (overwriting the committed copy), opposite of `bootstrap.sh`'s repo→home symlinking.
- New-laptop bootstrap has no role for it: there's no pre-existing `~/.zshrc` to migrate, and migration would destroy the repo's curated copy.

**Action:**
```bash
git rm profile_bootstrap
git commit -S -m "Remove profile_bootstrap: obsolete one-time migration script

Was the v0 bootstrap that adopted an existing ~/.zshrc into the
repo. Replaced by bootstrap.sh's symlink-based flow but never
deleted. Has been broken (exit 1 on every code path) since 2021.
No role in new-laptop bootstrap."
```

**Validation:** `./bootstrap.sh --dry-run` should still report identical actions.

**Time:** 2 minutes.

---

### Step 2 — De-hardcode `/Users/choco`

**Files:**
- `thefiles/.profile` — replace `/Users/choco` with `$HOME`
- `thefiles/.gitconfig` — replace with `~/` (modern git resolves `~`; verify with `git config --show-origin --get user.signingkey`)
- `thefiles/.zshrc` — replace `source /Users/choco/Documents/Workspaces/dotfiles/thefiles/.ansible_preauth` with `source ~/.ansible_preauth` (and add `.ansible_preauth` to `bootstrap.sh`'s `get_shell_files` whitelist)
- Audit `.aliases`, `.security`, `env_bootstrap.sh`, `bootstrap.sh` for any remaining literals — most already use `$USER`/`$HOME` correctly

**Validation:** new shell loads cleanly; `git commit -S` works; symlink for `.ansible_preauth` is created on next `bootstrap.sh --force` (existing absolute-path source becomes redundant — fine to leave or simplify).

**Time:** 15 minutes.

---

### Step 3 — Drop bash + windows + freebsd; KEEP zsh-on-Linux

**Reframed 2026-05-09** based on user feedback: Linux servers are a real "occasional but valued" use case. Dropping all non-macOS support would lose that. The actual dead branches are:
- bash (user is zsh-only)
- windows / freebsd in `.common_functions::detect_os` (never tested, never sourced)

zsh-on-Linux deserves first-class support: most of `.zshrc`, `.zsh_options`, `.zsh_keys`, `.profile`, `.exports`, `.aliases`'s `common()` block already work cross-platform.

**What's truly platform-specific and needs a Linux branch:**
- `.security` — touchid-agent / Secretive socket selection. On Linux, fall through to `gpg-agent` socket (`gpgconf --list-dirs agent-ssh-socket`) or generic `~/.ssh/agent.sock`.
- `.aliases::macos()` — Finder commands (`defaults write com.apple.finder...`), `bmaintain`, `provision_rpi`, the lwp-request HTTP method aliases. None of these make sense on Linux. The macOS block stays gated on `$(detect_os) = macos`.
- `bootstrap.sh::create_symlinks` `~/Workspaces` shortcut is macOS-specific (`/Users/$USER/Documents/...`). Either guard or reuse a portable `XDG_DOCUMENTS_DIR`-style env var.
- `env_bootstrap.sh` macos branch (Homebrew + `defaults write`) is macOS-only by definition. The `unix()` branch should install zsh, set up the touchid alternative, and otherwise no-op.

**Delete:**
- `thefiles/.bash_profile`, `thefiles/.bash_options`
- `bootstrap.sh::detect_shell` (always zsh; if user is on a Linux host without zsh, env_bootstrap installs it)
- `bootstrap.sh::get_shell_files` bash branch
- `thefiles/.common_functions` `windows` and `freebsd` branches (collapse to `macos` / `unix` only, with the `unix` label meaning "Linux or unknown POSIX")

**Keep:**
- `detect_os` returning `macos` or `unix` (collapse the `freebsd` weirdness)
- The OS dispatcher pattern in `.aliases` (it's actually useful for cross-platform configs)
- `env_bootstrap.sh`'s OS argument

**Status:** Not executing in this session. Update only — needs review on what to add to the `unix()` branch (gpg-agent fallback, Linux package install).

**Time when executed:** 45 minutes.

---

### Step 4 — Replace `.ansible_preauth`

**Reassessed 2026-05-09** based on user feedback ("have you really assessed deeply the workflow?").

#### The workflow this wrapper exists to enable

1. User runs ansible against many hosts (`--limit pis`, `all`, a group). Many = 5-30 in this homelab.
2. Each cold SSH connection requires a TouchID touch (the touchid-agent backs the SSH key in Secure Enclave; sshing to a host triggers a Mac-level biometric prompt).
3. Without a wrapper, ansible's default `forks=5` parallelism would issue 5 SSH connections concurrently, triggering 5 simultaneous TouchID prompts. The Touch ID API serializes prompts but the UX is chaotic, prompts can time out and ansible fails with auth errors mid-run, and lockouts can occur.
4. The wrapper's job: walk through the target host list **sequentially**, establish an SSH ControlMaster session for each (one TouchID prompt at a time, calmly, in foreground, with the user knowing which host is being touched for), and only then hand off to ansible. Once ControlMaster sessions exist with `ControlPersist 10m`, ansible's parallel forks multiplex through them — no further touch prompts during the playbook run.

#### The four properties the replacement MUST preserve

| # | Property | How current wrapper does it | How proposed wrapper does it |
|---|---|---|---|
| 1 | Identify exactly the hosts ansible will hit | Reimplements ansible's argv parser, group resolution, and inventory parsing in bash (~250 LOC, fragile, has the bugs catalogued above) | `command ansible/ansible-playbook "$@" --list-hosts` — delegates to ansible itself, so the list **definitionally** matches the run that follows |
| 2 | Iterate **sequentially** (one TouchID prompt at a time) | `for host in $hosts; do ...; done` (no `&`) | Same: `for h in $hosts; do ...; done` |
| 3 | For each host, establish a ControlMaster session | `ssh -O check` skip-if-warm, then `ssh -o ConnectTimeout=8 -o BatchMode=no "$host" "exit"` | `ssh -O check` skip-if-warm, then `ssh -fN -o ConnectTimeout=8 "$h"` (`-fN` = daemonize after auth, no command — the canonical idiom for ControlMaster warmup) |
| 4 | Then run ansible, which reuses warm sessions via `~/.ssh/control:%h:%p:%r` | `command ansible "$@"` | `command ansible "$@"` (identical) |

Result: every property preserved. The 326-line file becomes ~25 lines because the hard part (host extraction) is delegated to ansible.

#### Why `--list-hosts` is the right primitive

Verified empirically on 2026-05-09 with a synthetic inventory:

```
$ ansible -i inventory all --list-hosts
  hosts (3):
    web1.example.com
    web2.example.com
    db1.example.com
```

Single awk pattern extracts hostnames cleanly across both `ansible` and `ansible-playbook` output formats. Returns rc=0 with empty `hosts (0):` block on misconfigured inventory (so wrapper degrades gracefully — runs ansible directly, which surfaces the same error to the user).

#### Replacement (~25 lines, replaces all 326)

```bash
#!/bin/bash
# Pre-warm SSH ControlMaster sessions before Ansible runs.
# Sequential touchid prompts up front, so ansible's parallel forks
# can multiplex through warm sessions without triggering more.

# Extract hostnames from `ansible[-playbook] --list-hosts` output.
# Both formats put hostnames as indented bare tokens (no colon, no
# parentheses); group/play headers always have one of those.
__preauth_extract_hosts() {
  awk '/^[[:space:]]+[A-Za-z0-9._-]+$/ {gsub(/^[[:space:]]+/,""); print}'
}

# Warm one host: skip if ControlMaster already alive, else open a
# masked daemonized session that triggers a single touchid prompt.
__preauth_warm_host() {
  local h="$1"
  printf "  %-20s ... " "$h"
  if ssh -O check "$h" 2>/dev/null; then echo "✓ cached"; return; fi
  if ssh -fN -o ConnectTimeout=8 "$h" 2>/dev/null; then echo "✓"
  else echo "✗"; fi
}

ansible_preauth() {
  local cmd="$1"; shift
  local hosts
  hosts=$(command "$cmd" "$@" --list-hosts 2>/dev/null | __preauth_extract_hosts)
  [[ -z "$hosts" ]] && return 0
  echo "🔐 Pre-authenticating SSH sessions for Ansible..."
  while IFS= read -r h; do __preauth_warm_host "$h"; done <<< "$hosts"
}

ansible()          { ansible_preauth ansible          "$@"; command ansible          "$@"; }
ansible-playbook() { ansible_preauth ansible-playbook "$@"; command ansible-playbook "$@"; }
```

#### Edge cases analyzed

- **Recursion guard**: `command ansible` / `command ansible-playbook` bypass the function definitions. Without `command`, infinite recursion.
- **Bad inventory**: `--list-hosts` returns rc=0 with empty list. Wrapper skips warmup. Ansible itself surfaces the inventory error.
- **`--syntax-check` / `--list-tasks`**: wrapper still runs preauth (cost: ~1-3s for `--list-hosts`, then warmup loop is no-op for already-warm hosts). Harmless. Could optimize by detecting these flags and skipping; not worth the complexity.
- **Single host runs**: current wrapper has explicit "skip preauth if exactly one host" logic. New wrapper unconditionally calls `--list-hosts` then loops over one host. `ssh -O check` makes warm hosts free. For cold single hosts: one ssh-warmup vs one ansible-triggered TouchID — same UX.
- **Parallel ansible after warmup**: forks default to 5; each fork's ssh checks `~/.ssh/control:%h:%p:%r`, finds master, multiplexes. No new TouchID prompts. Workflow preserved.
- **Wrapper called from non-interactive context** (cron, CI): TouchID won't have a TTY. ssh fails fast under `-o ConnectTimeout=8`. Loop continues. Ansible run that follows will also fail. Same outcome as today.
- **Hosts in different inventory directories**: `--list-hosts` honors `-i` correctly because we pass `"$@"` through unchanged.

#### What we're explicitly losing

- The 1075 lines of unit + integration tests for the wrapper. They tested the bespoke argv parser and inventory grep that no longer exist. The new wrapper is small enough to validate by reading and by running against a real inventory.
- The "global skip if any control socket recent" guard. It was a no-op anyway (Bug C from the assessment) — `find -newer <(date ...)` always returns 0 matches.

**Status:** Not executing in this session. The replacement wrapper above is what step 4 will deploy when greenlit. After greenlight, plan is:
1. Create `thefiles/.ansible_preauth.new` with the replacement
2. Source from a fresh shell, run `ansible <real-group> --list-hosts` to confirm host extraction matches expectations
3. Run a real `--check` playbook against a small group; verify all touch prompts happen up-front, none mid-run
4. Mv `.ansible_preauth.new` → `.ansible_preauth`
5. `git rm thefiles/.scripts/test_ansible_*.sh`

**Time when executed:** 30 minutes wrapper + 30 minutes empirical validation against real inventory.

---

### Step 5 — Fix `env_bootstrap.sh` + add `Brewfile`

**Delete from `env_bootstrap.sh`:**
- `create_ssh_key` function (cleartext passphrase smell — never called anyway)
- `install_homebrew_apps` (replaced by Brewfile)
- The trailing zsh-config block in `macos()` (`compinit`, `bindkey -v`)
- The `unix()` and `common()` no-ops (after Step 3)

**Fix in `env_bootstrap.sh`:**
- `which brew 1>&/dev/null` → `command -v brew >/dev/null 2>&1`
- Cron entry: drop `source`, drop `sudo`, make idempotent:
  ```bash
  ( crontab -l 2>/dev/null | grep -v 'brew_maintain' ; \
    echo "0 1 * * * $HOME/.scripts/brew_maintain" ) | crontab -
  ```
- After Homebrew install: `brew bundle --file="${SCRIPT_DIR}/thefiles/Brewfile"`

**Create `thefiles/Brewfile`:**
```ruby
# CLI essentials
brew "git"
brew "gh"
brew "coreutils"        # gtimeout, gdate, etc.
brew "ripgrep"
brew "fd"
brew "bat"
brew "eza"
brew "fzf"
brew "zoxide"
brew "jq"
brew "yq"
brew "direnv"
brew "mise"
brew "starship"
brew "ansible"
brew "shellcheck"
brew "tree"

# Security
brew "1password-cli"
brew "mkcert"

# Cloudflare / web
brew "node"             # for wrangler
brew "cloudflared"

# Casks
cask "iterm2"
cask "iina"
cask "rectangle"
cask "raycast"
cask "1password"
cask "visual-studio-code"
cask "gpg-suite"
cask "secretive"        # if still used alongside touchid-agent
```

(Adjust to actual usage — the above is a sensible default for the user's profile, not a literal copy from inventory.)

**Validation:**
- On the current machine: `brew bundle --file=thefiles/Brewfile --no-upgrade` → "All dependencies are satisfied" (or shows missing ones to install).
- `crontab -l` shows exactly one `brew_maintain` line.
- `bash -n env_bootstrap.sh` passes.

**Time:** 1 hour.

---

### Step 6 — Modern CLI baseline

After Brewfile installs the tools, wire them into the shell:

**`thefiles/.zshrc` additions:**
```zsh
# Plugin manager (zinit minimal example; antidote also fine)
source <(zinit init)
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions

# Tool init
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"
eval "$(mise activate zsh)"
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
```

**`thefiles/.aliases` updates:**
- `alias ls='eza -lh --icons --git'`
- `alias cat='bat --paging=never'`
- `alias find='fd'`
- Drop the `for method in GET HEAD POST...` block
- Drop the custom `python()` function (mise handles it)

**`thefiles/.profile` cleanup:**
- Remove the hardcoded `/Users/choco/Library/Python/3.11/bin` (mise replaces it)
- Keep `$HOME/.local/bin` (used by pipx, etc.)

**Validation:** new shell prompts via Starship, `z <partial>` works, `Ctrl-R` opens fzf history.

**Time:** 1 hour.

---

### Step 7 — `docs/decisions.md` + shellcheck CI

**`docs/decisions.md`** — five one-liners covering:
- Why zsh-only (drop bash/unix abstraction)
- Why touchid-agent over Secretive as primary agent
- Why a thin Ansible wrapper over the previous heavy implementation
- Why mise over pyenv/asdf
- Why Brewfile over scripted `brew install` calls

**`.github/workflows/shellcheck.yml`** — single job, runs `shellcheck` on `bootstrap.sh`, `env_bootstrap.sh`, every file in `thefiles/` matching `.ansible_preauth`/`.scripts/*.sh`. Fails the build on findings.

**Validation:** workflow runs green on a fresh PR; if it doesn't, fix the findings (most should already be addressed by Steps 1-6).

**Time:** 30 minutes.

---

## Status tracker

- [x] 2026-05-07 — Initial assessment
- [x] 2026-05-09 — Plan stored at `docs/improvement-plan.md`
- [x] 2026-05-09 — `bootstrap.sh.bak` deleted (manual)
- [x] 2026-05-09 — Step 1: `profile_bootstrap` deleted (commit 971db61)
- [x] 2026-05-09 — Step 2: `/Users/choco` de-hardcoded; .gitconfig + .ansible_preauth added to symlink whitelist; bootstrap.sh `pwd -P` fix (commit 4f028e5)
- [ ] Step 3 — Drop bash/windows/freebsd; KEEP zsh-on-Linux **(awaiting decision on Linux unix() body)**
- [x] 2026-05-09 — Step 4: `.ansible_preauth` replaced with the 57-line wrapper. Validated against the live raspberrypi-ansible inventory (`ansible all -m ping`): 4 reachable hosts warmed in sequence with one TouchID prompt each; the subsequent ansible run multiplexed through the masters with zero further TouchID prompts. 2 stale inventory entries (`devpi`, `pihole`) failed fast in both warmup and ansible run with the same DNS/timeout errors — wrapper behavior is correct. Test scripts removed.
- [x] 2026-05-09 — Step 5: env_bootstrap.sh rewritten + Brewfile added (commit 0f0f3bb)
- [x] 2026-05-09 — Step 6: modern CLI baseline wired (guarded), shell-load defensive guards (commit cdeb59d)
- [x] 2026-05-09 — Step 7a: GitHub Actions lint workflow added
- [x] 2026-05-09 — Step 7b: scripts/validate.sh sandboxed validation harness added
- [ ] Step 7c — `docs/decisions.md` (5 one-liners)

All execution work is on branch `dotfiles-cleanup`. Validation: `scripts/validate.sh` reports 23 passed, 0 failed, 2 skipped (shellcheck not yet installed; Brewfile additions not yet `brew bundle`'d — both fixed by running `brew bundle --file=thefiles/Brewfile`).

## Open decisions

1. **Step 3 — what does the Linux `unix()` branch do?** Options: (a) install zsh + a Linux equivalent of the Brewfile via apt/dnf, (b) just symlink dotfiles and let the user manage packages manually, (c) ship a `Brewfile.linux` that `brew bundle` can consume since Homebrew now runs on Linux. Recommendation: **(b)** — minimal, predictable, and respects the "occasional Linux server" use case. Document in `docs/decisions.md`.
2. **Step 4 — when to swap the Ansible wrapper.** Recommendation: do it on a Saturday morning with `ansible all -m ping` against the real inventory as the validation. Then `git rm thefiles/.scripts/test_ansible_*.sh`.
