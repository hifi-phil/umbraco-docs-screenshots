#!/usr/bin/env bash
# Open a PR on the harness repo that adds this run's discovery dead ends to skip-images.txt.
#
# Usage: propose-skip-entries.sh <harness-root> "<basename>|<reason>" ["<basename>|<reason>" ...]
#
# Why: a run decides an image can never be recaptured (not reproducible, not a backoffice screen,
# deliberately old), but it must leave the harness checkout clean, so that verdict used to be lost
# and the next run picked the same image again. This records it as a reviewable PR instead.
#
# Works in a temporary worktree outside the repo, branched from origin/main, so the run's own
# checkout is never touched. Entries already in skip-images.txt on main, or pending in another open
# skip-images-* PR, are dropped. Prints the PR URL on success, or "nothing new" (exit 0) if every
# entry was already known.
#
# Exit 3 if gh is missing, 4 if the PR API call fails — the branch is already pushed by then, so
# open the PR with mcp__github__create_pull_request (head = the branch name printed on stderr).
# Uses REST, not GraphQL (`gh pr create`), which is blocked from Claude Code cloud sessions.

set -u

HARNESS="${1:-}"
shift 2>/dev/null || true
if [ -z "$HARNESS" ] || [ ! -d "$HARNESS/.git" ] || [ "$#" -eq 0 ]; then
  echo "Usage: propose-skip-entries.sh <harness-root> \"<basename>|<reason>\" ..." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_REL=".claude/skills/update-docs-screenshots/skip-images.txt"
SLUG=$(git -C "$HARNESS" remote get-url origin | sed -E 's#.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')

git -C "$HARNESS" fetch -q origin main || exit 1
KNOWN=$( { git -C "$HARNESS" show "origin/main:$SKIP_REL" 2>/dev/null; "$SCRIPT_DIR/list-pending-skips.sh" "$HARNESS"; } \
  | sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d')

LINES=""
for ENTRY in "$@"; do
  NAME="${ENTRY%%|*}"
  REASON="${ENTRY#*|}"
  [ "$NAME" = "$ENTRY" ] && REASON="dead end found by a discovery run"
  NAME="$(basename "$NAME")"
  if echo "$KNOWN" | grep -qxF "$NAME" || echo "$LINES" | grep -q "^$NAME "; then
    continue
  fi
  LINES="$LINES$(printf '%-34s # %s (discovery run %s)' "$NAME" "$REASON" "$(date +%d-%m-%Y)")
"
done
if [ -z "$LINES" ]; then
  echo "nothing new — every entry is already skipped or pending review"
  exit 0
fi

BRANCH="skip-images-$(date +%Y%m%d-%H%M%S)"
WT="$(mktemp -d)/harness"
cleanup() {
  git -C "$HARNESS" worktree remove --force "$WT" 2>/dev/null
  git -C "$HARNESS" branch -D "$BRANCH" >/dev/null 2>&1
}
trap cleanup EXIT

git -C "$HARNESS" worktree add -q -b "$BRANCH" "$WT" origin/main || exit 1
printf '%s' "$LINES" >> "$WT/$SKIP_REL"
git -C "$WT" add "$SKIP_REL"
git -C "$WT" commit -q -m "Skip discovery dead ends found by a scheduled run" || exit 1
git -C "$WT" push -q -u origin "$BRANCH" || exit 1
echo "pushed $BRANCH to $SLUG" >&2

command -v gh >/dev/null 2>&1 || { echo "gh CLI not found — open the PR for $BRANCH via MCP" >&2; exit 3; }
BODY="A scheduled discovery run tried these images and found they can't be recaptured. Merge to stop future runs picking them; close (or drop a line) if a verdict is wrong.

\`\`\`
${LINES}\`\`\`

While this PR is open, discovery runs already skip these images (scripts/list-pending-skips.sh)."
gh api -X POST "repos/$SLUG/pulls" -f title="[AI] Skip discovery dead ends" -f head="$BRANCH" \
  -f base=main -f body="$BODY" --jq .html_url || exit 4
