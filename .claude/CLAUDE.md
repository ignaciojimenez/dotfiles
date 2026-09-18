@~/.agent-context/AGENTS.md

# Claude Code specifics

Claude Code reads `CLAUDE.md`, not `AGENTS.md` — hence this file. It imports
the canonical context above; anything below is Claude-Code-only and does not
belong in the portable file.

`~/.agent-context` is a symlink to `dotfiles/agent-context/`, created by
`bootstrap.sh`. That indirection keeps this import valid no matter where the
repo is cloned or which user runs it.

- Config lives in `~/.claude/settings.json` (machine-specific, not tracked):
  model `opus`, `effortLevel: high`, theme `dark-ansi`.
- Plugins: commit-commands, playwright, slack, clangd-lsp, cloudflare
  (marketplace `cloudflare/skills`), and `agent-sessions` — a hooks-only plugin
  linked from this repo by `bootstrap.sh`; see `docs/agent-sessions.md`.
