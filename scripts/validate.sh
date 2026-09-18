#!/bin/bash
# Read-only validation harness. Runs every check from CI plus a couple
# more, all against the working tree, with zero side effects on the
# user's environment:
#
#   * No installs (brew bundle is `check`/`list` only).
#   * No filesystem changes (bootstrap is `--dry-run` only).
#   * No shell rc execution against the live $HOME — sandboxed shells
#     get a temporary $HOME that's torn down on exit.
#
# Usage:
#   scripts/validate.sh           # run everything
#   scripts/validate.sh --quick   # syntax checks only (skips brew)
#
# Exit code: 0 if every check passes, non-zero otherwise.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

ok()    { echo -e "${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail()  { echo -e "${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
skip()  { echo -e "${YELLOW}⊘${NC} $1"; SKIP=$((SKIP+1)); }
section() { echo -e "\n${BLUE}═══ $1 ═══${NC}"; }

# Files we lint. Keep in sync with .github/workflows/lint.yml.
BASH_FILES=(
  bootstrap.sh
  env_bootstrap.sh
  thefiles/.ansible_preauth
  thefiles/.aliases
  thefiles/.common_functions
  thefiles/.exports
  thefiles/.profile
  thefiles/.security
  thefiles/.shell_options
  thefiles/.shell_tools
  thefiles/.scripts/brew_maintain
  thefiles/.scripts/ansible-vault-pass
  thefiles/.scripts/agent-sessions
  scripts/test-agent-sessions.sh
)

ZSH_FILES=(
  thefiles/.zshrc
  thefiles/.zprofile
  thefiles/.zsh_options
  thefiles/.zsh_keys
)

# ─── 1. bash -n syntax check ─────────────────────────────────────────────────
section "bash -n syntax"
for f in "${BASH_FILES[@]}"; do
  if [[ -f "$f" ]] && bash -n "$f" 2>/tmp/validate-err.$$; then
    ok "$f"
  elif [[ -f "$f" ]]; then
    fail "$f"
    sed 's/^/    /' /tmp/validate-err.$$
  else
    skip "$f (missing)"
  fi
done
rm -f /tmp/validate-err.$$

# ─── 2. zsh -n syntax check ──────────────────────────────────────────────────
section "zsh -n syntax"
if command -v zsh >/dev/null; then
  for f in "${ZSH_FILES[@]}"; do
    if [[ -f "$f" ]] && zsh -n "$f" 2>/tmp/validate-err.$$; then
      ok "$f"
    elif [[ -f "$f" ]]; then
      fail "$f"
      sed 's/^/    /' /tmp/validate-err.$$
    else
      skip "$f (missing)"
    fi
  done
  rm -f /tmp/validate-err.$$
else
  skip "zsh not installed"
fi

# ─── 3. shellcheck ───────────────────────────────────────────────────────────
section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck --shell=bash --severity=warning \
                --exclude=SC1090,SC1091,SC2155 \
                "${BASH_FILES[@]}" >/tmp/validate-err.$$ 2>&1; then
    ok "no warnings"
  else
    fail "issues found"
    sed 's/^/    /' /tmp/validate-err.$$
  fi
  rm -f /tmp/validate-err.$$
else
  skip "shellcheck not installed (brew install shellcheck)"
fi

# ─── 4. Sandboxed shell load ─────────────────────────────────────────────────
# Spawn a zsh that uses a throwaway $HOME containing symlinks to the
# repo's dotfiles. Proves the rc files load with no errors and don't
# touch the user's real $HOME.
section "sandboxed shell load"
if command -v zsh >/dev/null; then
  SANDBOX="$(mktemp -d -t dotfiles-validate.XXXXXX)"
  trap 'rm -rf "$SANDBOX"' EXIT
  for f in .zshrc .zprofile .zsh_options .zsh_keys .profile .exports \
           .common_functions .security .aliases .shell_options \
           .ansible_preauth .scripts; do
    [[ -e "$ROOT/thefiles/$f" ]] && ln -s "$ROOT/thefiles/$f" "$SANDBOX/$f"
  done
  if HOME="$SANDBOX" zsh -i -c ': loaded' 2>/tmp/validate-err.$$; then
    ok "interactive zsh loads cleanly with sandboxed \$HOME"
    [[ -s /tmp/validate-err.$$ ]] && {
      echo "    (warnings suppressed — non-fatal:)"
      sed 's/^/    /' /tmp/validate-err.$$
    }
  else
    fail "interactive zsh failed to load"
    sed 's/^/    /' /tmp/validate-err.$$
  fi
  if HOME="$SANDBOX" zsh -l -c ': loaded' 2>/tmp/validate-err.$$; then
    ok "login zsh loads cleanly with sandboxed \$HOME"
  else
    fail "login zsh failed to load"
    sed 's/^/    /' /tmp/validate-err.$$
  fi
  rm -f /tmp/validate-err.$$
else
  skip "zsh not installed"
fi

# ─── 5. Bootstrap dry-run ────────────────────────────────────────────────────
section "bootstrap.sh --dry-run"
if out=$(./bootstrap.sh --dry-run 2>&1); then
  if grep -qE "(error|Error|ERROR)" <<< "$out"; then
    fail "errors in dry-run output"
    echo "$out" | sed 's/^/    /'
  else
    ok "completes cleanly"
  fi
else
  fail "exited non-zero"
  echo "$out" | sed 's/^/    /'
fi

# ─── 6. Agent context budget ─────────────────────────────────────────────────
# The canonical file is symlinked into Devin Desktop (Windsurf) at
# ~/.codeium/windsurf/memories/global_rules.md, which caps global rules at
# 6,000 characters. Over budget it would be silently truncated there while
# still looking fine everywhere else — so fail loudly here instead.
section "agent context"
AGENT_CTX="agent-context/AGENTS.md"
AGENT_CTX_MAX=6000
if [[ -f "$AGENT_CTX" ]]; then
  chars=$(wc -c < "$AGENT_CTX" | tr -d ' ')
  if [[ "$chars" -le "$AGENT_CTX_MAX" ]]; then
    ok "$AGENT_CTX within budget ($chars/$AGENT_CTX_MAX chars)"
  else
    fail "$AGENT_CTX over budget ($chars/$AGENT_CTX_MAX chars) — would truncate in Windsurf"
  fi
  # The importer must actually import, or Claude Code silently loses everything.
  if grep -q '^@~/.agent-context/AGENTS.md' .claude/CLAUDE.md 2>/dev/null; then
    ok ".claude/CLAUDE.md imports the canonical context"
  else
    fail ".claude/CLAUDE.md is missing the @~/.agent-context/AGENTS.md import"
  fi

  # Both checks above pass on a machine where every agent is reading some other
  # file entirely: one greps the importer's text, the other measures the repo's
  # copy. Neither asks the only question that matters — does the path the import
  # names actually land in this repo?
  #
  # It did not, for three months. ~/.agent-context pointed at an iCloud folder
  # holding an untracked August copy; Windsurf had a standalone file from
  # February; opencode, devin and gemini had nothing at all. Every check was
  # green throughout. Assert the wiring, not the text.
  if ! readlink -f / >/dev/null 2>&1; then
    skip "agent context wiring (readlink -f unavailable)"
  elif [[ ! -e "$HOME/.agent-context" ]]; then
    # Nothing bootstrapped here — CI, or a fresh clone. Not a failure.
    skip "agent context wiring (bootstrap has not run on this machine)"
  else
    wiring_ok=1
    for adapter in \
      "$HOME/.agent-context:$ROOT/agent-context" \
      "$HOME/.config/opencode/AGENTS.md:$ROOT/agent-context/AGENTS.md" \
      "$HOME/.config/devin/AGENTS.md:$ROOT/agent-context/AGENTS.md" \
      "$HOME/.gemini/AGENTS.md:$ROOT/agent-context/AGENTS.md" \
      "$HOME/.codeium/windsurf/memories/global_rules.md:$ROOT/agent-context/AGENTS.md" \
      "$HOME/.claude/CLAUDE.md:$ROOT/.claude/CLAUDE.md"
    do
      link="${adapter%%:*}"; want="${adapter#*:}"
      got="$(readlink -f "$link" 2>/dev/null || true)"
      if [[ "$got" != "$want" ]]; then
        fail "${link/#$HOME/~} -> ${got:-(missing)}, expected ${want/#$ROOT/.}"
        wiring_ok=0
      fi
    done
    [[ "$wiring_ok" -eq 1 ]] && ok "all 6 agent-context adapters resolve into this repo"
  fi
else
  fail "$AGENT_CTX not found"
fi

# ─── 7. Agent sessions ───────────────────────────────────────────────────────
# The contract test replays real hook payload shapes through the tracker. The
# wiring check asks what the 2026-09-18 failure taught: not whether the files
# look right, but whether Claude Code would actually load them.
section "agent sessions"
if command -v jq >/dev/null && command -v git >/dev/null; then
  if out=$(scripts/test-agent-sessions.sh 2>&1); then
    ok "contract test ($(tail -n 1 <<<"$out" | sed 's/^ *//'))"
  else
    fail "contract test"
    echo "$out" | sed 's/^/    /'
  fi
else
  skip "contract test (needs jq and git)"
fi
if ! readlink -f / >/dev/null 2>&1; then
  skip "agent-sessions wiring (readlink -f unavailable)"
elif [[ ! -e "$HOME/.agent-context" ]]; then
  skip "agent-sessions wiring (bootstrap has not run on this machine)"
else
  plugin="$HOME/.claude/skills/agent-sessions"
  got="$(readlink -f "$plugin" 2>/dev/null || true)"
  hook="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$plugin/hooks/hooks.json" 2>/dev/null |
          sed -E 's/^"([^"]*)".*/\1/; s|\$HOME|'"$HOME"'|')"
  if [[ "$got" != "$ROOT/agent-sessions/claude" ]]; then
    fail "${plugin/#$HOME/~} -> ${got:-(missing)}, expected ./agent-sessions/claude"
  elif [[ ! -x "$hook" ]]; then
    fail "hook command ${hook:-(unreadable)} is not executable"
  else
    ok "agent-sessions plugin linked into ~/.claude/skills, hook command executable"
  fi
fi

# ─── 8. Brewfile parses + check ──────────────────────────────────────────────
if [[ "$QUICK" -eq 0 ]]; then
  section "Brewfile (read-only)"
  if [[ -f thefiles/Brewfile ]]; then
    if command -v brew >/dev/null; then
      if brew bundle list --file=thefiles/Brewfile >/dev/null 2>&1; then
        ok "parses"
      else
        fail "parse failed"
      fi
      # `check` is read-only — reports missing items; doesn't install.
      missing=$(brew bundle check --verbose --file=thefiles/Brewfile 2>&1 | grep -c '^→' || true)
      if [[ "$missing" -eq 0 ]]; then
        ok "all dependencies satisfied"
      else
        skip "$missing item(s) need install (run \`brew bundle --file=thefiles/Brewfile\`)"
      fi
    else
      skip "brew not installed"
    fi
  else
    skip "thefiles/Brewfile not present"
  fi
else
  section "Brewfile (skipped — --quick)"
  skip "use without --quick to check Brewfile"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo
echo -e "${BLUE}═══ summary ═══${NC}"
echo -e "  passed:  ${GREEN}$PASS${NC}"
[[ "$FAIL" -gt 0 ]] && echo -e "  failed:  ${RED}$FAIL${NC}" || echo -e "  failed:  $FAIL"
[[ "$SKIP" -gt 0 ]] && echo -e "  skipped: ${YELLOW}$SKIP${NC}" || echo -e "  skipped: $SKIP"

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
