@~/.agent-context/AGENTS.md

# Claude Code specifics

Claude Code reads `CLAUDE.md`, not `AGENTS.md` — hence this file. It imports
the canonical context above; anything below is Claude-Code-only and does not
belong in the portable file.

`~/.agent-context` is a symlink to `dotfiles/agent-context/`, created by
`bootstrap.sh`. That indirection keeps this import valid no matter where the
repo is cloned or which user runs it.

- Settings are tracked in `harness/claude/settings.json`, linked to
  `~/.claude/settings.json` by `bootstrap.sh`. Model, effort, plugins and
  auto-mode rules live there and are deliberately not restated here.
- `agent-sessions` is a hooks-only plugin linked from this repo by
  `bootstrap.sh`; see `docs/agent-sessions.md`.
