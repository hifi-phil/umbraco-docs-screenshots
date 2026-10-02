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
#   3 — gh CLI not available. Use the mcp__github__* fallback (references/github-fallback.md).
#   4 — gh is installed but the API call failed (auth, network). Also use the MCP fallback.
#       Exits 3/4 fail loudly on purpose: an earlier version let a failed lookup fall through
#       silently (empty count compared with -ge still reached `exit 0`), bypassing the guard.
#
# Uses the REST API (`gh api .../pulls`), not `gh pr list`: `gh pr list` is GraphQL-backed, and
# GraphQL is blocked from Claude Code cloud sessions (403 "GitHub GraphQL is not available from
# Claude Code sessions") — which made this script fail on every scheduled run. REST works both
# locally and in the cloud.
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
  echo "gh CLI not found — use the mcp__github__* fallback (references/github-fallback.md) instead." >&2
  exit 3
fi

# Open PRs on upstream whose head is a fork-owned update-screenshot-* branch. --paginate applies
# --jq per page, so emit one line per match and count lines rather than summing per-page lengths.
JQ=".[] | select(.user.login == \"$FORK_OWNER\" and (.head.ref | startswith(\"update-screenshot-\"))) | \"  #\\(.number)  \\(.html_url)\""
if ! MATCHES=$(gh api --paginate "repos/umbraco/UmbracoDocs/pulls?state=open&per_page=100" --jq "$JQ"); then
  echo "gh api call failed — use the mcp__github__* fallback (references/github-fallback.md) instead." >&2
  exit 4
fi
OPEN=$(printf '%s\n' "$MATCHES" | grep -c '#' || true)

echo "Open screenshot PRs: $OPEN (limit $MAX_OPEN)"

if [ "$OPEN" -ge "$MAX_OPEN" ]; then
  [ -n "$MATCHES" ] && printf '%s\n' "$MATCHES"

  if [ "$MODE" = "discovery" ] || [ "$MODE" = "slack" ]; then
    echo "STOP: reviewer-load guard tripped in $MODE mode — end the run now." >&2
    exit 1
  else
    echo "WARN: targeted mode — this run will stack another screenshot PR on top of the above." >&2
    exit 0
  fi
fi

exit 0
