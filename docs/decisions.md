# Decisions

One-liner record of architecture/strategy calls. Newest first.

## 2026-09-17

- **Who may close depends on who initiated, not only on the label.** The rule said no agent ever closes an issue Ignacio owns. A session he explicitly pointed at `PER-60` did the work, tested it, deployed it and closed it — correctly, and against the letter of the contract. The rule was written for an *unattended sweep*, which must never retract work it cannot judge; applying it to a session he asked for buys no safety and makes him re-close everything he delegates. Narrowed: a sweep never closes his issues, a session he asked may once it has verified, and `In Review` now means specifically *an agent believes this is done and nobody asked it to*.
- **The contract was found wrong by reading a transcript, not by asking how it went.** He reported no friction. The session log showed it: two human messages, and four `Artifact` calls maintaining a dashboard the Linear move exists to retire, because a stale `SessionStart` hook still called that artifact the primary queue. Outcome-watching would never have surfaced either — the work was clean and the waste was in tool calls nobody sees.
- **`agent-context/AGENTS.md` is at 5,976 of 6,000 characters.** The next thing added has to displace something. That is the budget working as intended, but it means the canonical file is now full and further rules belong in `docs/queue.md` behind the pointer.

## 2026-09-06

- **Linear is the queue; this repo holds the protocol that makes it usable.** The queue itself lives in Linear (team `PER`), but the *instructions* for operating it belong here, because `agent-context/AGENTS.md` is the one file every harness loads and the one thing a new laptop bootstraps. Split in two on purpose: the behaviour-changing minimum goes in the budgeted canonical file — where the queue is, that `Todo` is all of it, that no project means untriaged, and above all **which labels permit an agent to close an issue** — while the full protocol, queries and known gaps go in `docs/queue.md`. Passes the standing content test: this changes what an agent *does*, unlike the hostnames and channel names that were removed on 2026-08-04. The canonical file is now 5,777/6,000 chars, so the next addition must displace something.
- **The queue records what is not built, not only what is.** `docs/queue.md` states plainly that nothing writes to the queue automatically and that auto-close, the key→issue map and the run heartbeat are designed and unbuilt. Without that, an agent reading about `agent/*` labels reasonably infers a reconciler exists and trusts an absence of issues as evidence of health — which is the "a check that does nothing is also silent" failure applied to the tracker itself.

## 2026-08-04

- **`$TERM` belongs to the terminal; we neither force it nor assume it.** Two halves of one bug, fixed together. `.zsh_keys` exported `TERM=xterm-256color`, clobbering whatever the terminal actually advertised — a downgrade under tmux (`tmux-256color`) or kitty, and wrong in principle since the terminal is the authority. Deleted rather than moved to `.exports`: `.exports` is reached via `.profile` by *non-interactive* logins, so moving it would have forced `TERM` into cron and `ssh host 'cmd'` contexts where it should stay unset — worse than the original. Removing it then exposed the half it had been masking: `.exports` ran `tput` unguarded, writing to stderr on every login shell with no `$TERM`. Invisible on macOS, but `.profile` is sourced by non-interactive logins on every Linux host, making it a plausible false-alarm source for monitoring that greps stderr. Now guarded on `$TERM` being set and not `dumb`. Verified on Debian 13 / bash 5.2 (stderr clean with TERM unset and with `TERM=dumb`; `LESS_TERMCAP_md` still populated when TERM is real) and on macOS zsh (`tmux-256color` now survives intact).
- **zsh is a target, not a prerequisite. `bootstrap.sh` warns instead of aborting.** It used to `exit 1` when zsh was missing, which denied *everything* — `.profile`, `.gitconfig`, `.scripts/`, the agent context — over the four files that actually need zsh, and denied it precisely on the hosts least able to fix it: a container or a shared box where installing a shell needs root you may not have. Verified the split before changing it: 4 of 14 tracked files are zsh-specific and are inert (not broken) without it, while `.profile` is POSIX and confirmed read by login bash, and `.gitconfig` is confirmed picked up by git. Linking unconditionally also means the zsh files start working the moment zsh is installed, with no second run. Does **not** revisit the 2026-05-09 zsh-only call: the shell config stays zsh-only: this is about the gate, not the target.
- **Portable AI agent context lives in this repo; git is the transport. Supersedes the 2026-06-13 iCloud call.** The canonical file is `agent-context/AGENTS.md`, tracked and public. The iCloud vault is dropped entirely. Reason the previous decision failed: `bootstrap.sh` gated the whole wiring on macOS because iCloud has no Linux client, so a Linux agent host — the case that motivated this — could never receive the context at all. Git reaches every platform; iCloud reaches one. Secondary wins: real history, diffs and rollback on the content that actually matters, and no `/Users/<name>/` hardcode.
- **One canonical file, budgeted at 6,000 characters.** That is Devin Desktop's (Windsurf's) cap on `global_rules.md`; staying under it means every harness gets the identical file verbatim, with no per-harness variants to drift. `scripts/validate.sh` fails the build if it grows past the budget, because over-budget content would be silently truncated in Windsurf while looking correct everywhere else. It also converges with Claude Code's own guidance that shorter context files get better adherence.
- **Content test is "does this change what an agent does", not "is this private".** Verified first that the personal details were already public in `ignaciojimenez/ignaciojimenez` and that the homelab topology was already public in `infrastructure-automation` — so withholding them protected nothing. What left the file left because it is inventory an agent never acts on (specific hostnames, bucket and channel names), not because it is sensitive. Machine-specific inventory belongs in that machine's own repo.
- **Adapters are symlinks, created unconditionally on every host.** A dangling adapter for an uninstalled harness is inert, and pre-wiring makes adopting a new harness free. `~/.agent-context` → `agent-context/` is the one indirection everything else points through, which is what keeps the wiring free of usernames and clone paths.
- **`~/.gemini/GEMINI.md` is deliberately not linked.** Antigravity and Gemini CLI both read *and write* that exact path (google-gemini/gemini-cli#16058); a symlink would let Antigravity's "+ Global" button overwrite the tracked file. Gemini CLI is pointed at `~/.gemini/AGENTS.md` via `context.fileName` instead, leaving `GEMINI.md` to Antigravity.
- **Drift was measured, not assumed.** Three divergent copies of the same preferences existed: the iCloud `AGENTS.md` (8.1 KB), `~/.gemini/GEMINI.md` (1.6 KB, Jan 2026) and `~/.codeium/windsurf/memories/global_rules.md` (1.8 KB, Feb 2026) — the last two sharing a common ancestor but having gained different rules since. Everything unique to them was folded into the canonical file before they were replaced.

## 2026-06-13

- **Portable AI agent context lives in iCloud; the repo owns only the wiring.** The single source of truth (`AGENTS.md`, agent-neutral, read by Claude Code and other agents) sits in the iCloud Drive vault `AgentContext/` and is intentionally NOT tracked here — iCloud owns the content, syncs it across devices, and keeps it out of a public repo. `bootstrap.sh` (macOS-only; iCloud has no Linux client) wires it up: `~/.agent-context` → the iCloud vault, and `~/.claude/CLAUDE.md` → a tracked one-line file that `@`-imports the vault's `AGENTS.md`. The wiring file is the *only* `.claude/` content committed; `settings.local.json` is gitignored.

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

- **Revisit the "Linux is graceful-degradation secondary" call (2026-05-09).** It predates
  running agents on Linux hosts. The context wiring is now cross-platform, but
  `env_bootstrap.sh unix()` is still a deliberate no-op, so a fresh Linux agent host gets
  symlinks and no tooling. Decide whether that stays true now that Linux is somewhere real
  work happens rather than just somewhere to ssh into. Three concrete data points, all found
  only once Linux became a real target: the `require_zsh` hard gate, the absence of any
  `.bashrc`, and the unguarded `tput` in `.exports`. Related open question that belongs in
  `infrastructure-automation`, not here: whether `apt install zsh` plus the dotfiles clone
  get codified into the agent-lxc Ansible role, or stay a manual step.
- **Context portability beyond the filesystem.** Symlinks solve "same context on every host I
  can clone to". They don't reach phones, web UIs, or hosted agents. Open problem: one
  source of truth that moves seamlessly across devices *and* interfaces. Nearest thing today
  is reading the file from GitHub; that isn't a real answer yet.

Cosmetic/stylistic. None blocking, none insecure.

- `setopt CORRECT` / `CORRECT_ALL` in `.zsh_options` — drop unless you actually use the "did you mean…" prompt.
- Custom `python()` in `.aliases` macos block — overrides pyenv shims to fall back to `/usr/bin/python3`. Decide which one is authoritative and drop the other.
- `lwp-request`-based `GET`/`POST`/… aliases in `.aliases` — replace with `httpie` or just remove.
- `EDITOR='vim'` set in `.profile` but no `.vimrc` tracked. Commit one or switch editor.
- `brew bundle cleanup --file=thefiles/Brewfile --dry-run` periodically to reconcile drift.
