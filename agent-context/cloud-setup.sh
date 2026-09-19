#!/bin/bash
# Setup script for hosted Claude Code cloud environments.
#
# This file is the source of truth; the environment dialog at claude.ai/code
# holds a pasted copy. Anyone using the environment can read it: no secrets.
#
# Hosted sessions load only what is in the clone, never ~/.claude/CLAUDE.md,
# so agent-context/AGENTS.md does not reach them. This installs a user-level
# SessionStart hook in the VM that fetches the file on every session start.
#
# Why a hook and not a copy: the setup script runs once, then its filesystem
# is snapshotted and reused for ~7 days. A copy written here would go stale
# silently, the failure recorded in docs/decisions.md on 2026-09-18.
set -eu

url=${AGENTS_MD_URL:-https://raw.githubusercontent.com/ignaciojimenez/dotfiles/master/agent-context/AGENTS.md}
hook=${AGENTS_MD_HOOK:-/usr/local/bin/agents-md-context}
settings=$HOME/.claude/settings.json

cat > "$hook" <<EOF
#!/bin/bash
# SessionStart hook: plain stdout becomes session context.
if body=\$(curl -fsS --max-time 10 '$url'); then
  printf '%s\n\n%s\n' '# Global agent context, fetched from $url' "\$body"
else
  echo "WARNING: could not fetch global AGENTS.md from $url. Ignacio's global rules are NOT loaded in this session. Say so before doing any work."
fi
EOF
chmod 755 "$hook"

# Merge rather than overwrite: the image may ship its own user settings.
mkdir -p "$(dirname "$settings")"
python3 - "$settings" "$hook" <<'PY'
import json, os, sys
path, hook = sys.argv[1], sys.argv[2]
settings = json.load(open(path)) if os.path.exists(path) else {}
entry = {"hooks": [{"type": "command", "command": hook, "timeout": 30}]}
starts = settings.setdefault("hooks", {}).setdefault("SessionStart", [])
if entry not in starts:
    starts.append(entry)
json.dump(settings, open(path, "w"), indent=2)
PY

echo "cloud-setup: SessionStart hook $hook registered in $settings"
