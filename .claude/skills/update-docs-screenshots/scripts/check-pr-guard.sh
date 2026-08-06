#!/usr/bin/env bash
# Count open update-docs-screenshots PRs and apply the reviewer-load guard (Step 2).
#
# Usage: check-pr-guard.sh <discovery|targeted|slack> <fork-owner> [max-open]
#
# Exit codes:
#   0 — proceed (guard not tripped, or targeted mode where it's only a warning)
#   1 — STOP: discovery or slack mode and the guard tripped. End the run; do not explore, capture,
#       resolve a Slack message, or open anything.
#   2 — bad arguments
#   3 — gh CLI not available. This script is the LOCAL path only (see SKILL.md Step 2) — on
#       Claude web / a scheduled routine, gh isn't installed and this must not be called at all;
#       use the mcp__github__* fallback SKILL.md documents instead. Fails loudly on purpose: an
#       earlier version let this fall through silently (empty count compared with -ge produced a
#       shell error but still reached `exit 0`), meaning the reviewer-load guard was silently
#       bypassed on every cloud run instead of stopping anything.
#
# Screenshot PRs are identified by the `update-screenshot-*` branch prefix used in Step 9 — keep
# that prefix in sync with tests/PR-creation code so this guard keeps working.

set -u

MODE="${1:-}"
FORK_OWNER="${2:-}"
MAX_OPEN="${3:-8}"

case "$MODE" in
  discovery|targeted|slack) ;;
  *)
    echo "Usage: check-pr-guard.sh <discovery|targeted|slack> <fork-owner> [max-open]" >&2
    exit 2
    ;;
esac
if [ -z "$FORK_OWNER" ]; then
  echo "Usage: check-pr-guard.sh <discovery|targeted|slack> <fork-owner> [max-open]" >&2
  exit 2
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found — this is the local-only path. Use the mcp__github__* fallback (SKILL.md Step 2) instead of calling this script." >&2
  exit 3
fi

OPEN=$(gh pr list --repo umbraco/UmbracoDocs --author "$FORK_OWNER" --state open \
        --json number,headRefName \
        -q '[.[] | select(.headRefName | startswith("update-screenshot-"))] | length')

echo "Open screenshot PRs: $OPEN (limit $MAX_OPEN)"

if [ "$OPEN" -ge "$MAX_OPEN" ]; then
  gh pr list --repo umbraco/UmbracoDocs --author "$FORK_OWNER" --state open \
    --json number,headRefName,url \
    -q '.[] | select(.headRefName | startswith("update-screenshot-")) | "  #\(.number)  \(.url)"'

  if [ "$MODE" = "discovery" ] || [ "$MODE" = "slack" ]; then
    echo "STOP: reviewer-load guard tripped in $MODE mode — end the run now." >&2
    exit 1
  else
    echo "WARN: targeted mode — this run will stack another screenshot PR on top of the above." >&2
    exit 0
  fi
fi

exit 0
