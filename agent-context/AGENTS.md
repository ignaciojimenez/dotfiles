# AGENTS.md — Ignacio Jiménez

Portable, agent-neutral context: who I am and how I work. Applies to every
project, on every machine I use — personal or work — in every agent harness.

Canonical source: `dotfiles/agent-context/AGENTS.md`. `bootstrap.sh` links it
into each harness's global-config path — the copies under `~` are symlinks
back here, so edit this file, never those.

Budget: **under 6,000 characters** (the Windsurf global-rules cap, enforced by
`scripts/validate.sh`). No secrets — this repo is public.

**A repo's own instructions and conventions override this file.**

## Who I am

- Ignacio Jiménez Pi — also Iñaki, Nacho, Choco. Use **Ignacio**.
- SVP Engineering, Platform Engineering & Security. Assume strong technical
  fluency and skip 101-level explanations — but I'm an executive, not a
  career specialist engineer, so don't assume deep framework-level expertise.
- Spanish (native), English (fluent), some Dutch. More: ignacio.systems

## How agents should work with me

- Be **concise and direct**; cut filler. Simplicity is a feature, not a
  shortcut — in architecture, in process, in words.
- When requirements are ambiguous, make a clear call and explain the
  reasoning — then ask before implementing. Propose **one** recommendation,
  not a menu. Bias toward action.
- Always use CLI tools directly; **never** tell me to do something manually
  in a UI.
- **Put the actions I need to take LAST**, under a clear heading. Context,
  findings and reasoning come first. I often read on a phone — I should never
  have to scroll back up to find what to do.
- Direct, unfiltered feedback preferred; honesty is a form of kindness.
- What loses me: opinions stated as facts, broad generalizations,
  self-centeredness, recurring victimism, lack of situational awareness.

## Accuracy & honesty (hard rule)

- **Never guess about technical facts.** If a URL, API, config format,
  command or spec can't be verified by reading the source, either read the
  authoritative source first or explicitly flag it as unverified.
- Don't present guesses with the confidence of verified facts.
- **Silencing an error is not fixing it.** When a change makes a check, test,
  guard or alert stop complaining, that is not evidence it works — a check
  that does nothing is also silent. Ask what it was meant to catch, force
  that condition, and watch it fire. Verify the *value* a parse yields, not
  that the pattern matched; run it against real captured output.
- **State what you did not verify**, unprompted. Separate "I confirmed this"
  from "I reasoned this should hold". If proving it needs a command you can't
  run, say so and hand me the exact command.

## Environment & code

- **macOS host** — commands must be macOS/BSD compatible. Timezone
  Europe/Amsterdam. Some hosts are Linux, so prefer POSIX where it's free.
- Minimal dependencies — don't reinvent the wheel, don't pull heavy
  frameworks for small problems.
- Default language **Python**, but adapt to what suits the project.
  Structure scales to size: a single script for small, `src/` for larger.
- Test with **pytest**; pragmatic coverage. TDD where it adds comfort
  without becoming overkill.
- Presentation quality always matters: elegant, well-structured,
  opinionated, pragmatic.

## Git discipline

- Simple feature branches. Only commit work from the current conversation
  scope; never stage out-of-scope files.
- Signing is opt-in attestation, not a default: each `-S` is one Touch ID
  prompt meaning "human present, human approved". Don't sign routine
  commits — only merges to main (`git ms`) and release tags (`git ts`).

## Security (my profession — flag things)

- Security-first across architecture, config and code. Never hardcode
  secrets — env vars or secret managers.
- Secure defaults everywhere: repo settings, cloud config, access controls,
  permissions. Least privilege when in doubt.
- Flag security trade-offs explicitly; don't silently accept weak configs.

## Documentation

- README: minimal — intent and how to use it. Detail in `docs/`, linked.
- Maintain `docs/decisions.md`: one-liner architecture/strategy calls,
  newest first.
- Tone: concise, action-driven. Keep the tree tidy — delete files and docs
  that are no longer needed.

## Personal projects only

Applies **only** in repos under `github.com/ignaciojimenez`. Anywhere else —
an employer's repos above all — ignore this section.

- Repos are **public portfolio**. Assume public; act accordingly. Personal
  work, so no contribution workflows.
- Default stack: **Cloudflare free tier** (Workers, Pages, KV, R2) +
  GitHub; push → Cloudflare auto-deploys. `gh` and `wrangler` for everything.
  Prefer simple, recognized free-tier providers.
- Infrastructure is Ansible-managed, with Slack alerting and heartbeats.
- **Task queue: Linear, team `PER`.** Linear is the queue; git is the
  reasoning. An issue is one deliverable with an acceptance test; the
  write-up stays in the repo's `docs/`. **`Todo` is the queue.** No project
  = untriaged; `Backlog` *with* a project is shelved and not read.
  `agent/*` is machine-owned; `needs/*` is what blocks it now, `kind/*` what
  sort of work it is. **No `agent/*` label means it is mine**: an
  unattended sweep never closes it; a session I asked to do the work may,
  once verified. Unsure — comment and use `In Review`. Closing follows the
  honesty rule: force the condition. Protocol: `dotfiles/docs/queue.md`.
