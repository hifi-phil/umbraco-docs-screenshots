#!/usr/bin/env bash
# Print the basenames that open skip-images-* PRs on the harness repo would add to skip-images.txt.
#
# Usage: list-pending-skips.sh <harness-root>
#
# Why: a dead end proposed by scripts/propose-skip-entries.sh should stop being picked straight
# away, not only once a reviewer merges the PR. Closing the PR without merging lets the image back
# in. Prints nothing (exit 0) if gh is missing or the API call fails — the skip file still applies.

set -u

HARNESS="${1:-}"
[ -n "$HARNESS" ] || { echo "Usage: list-pending-skips.sh <harness-root>" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || exit 0
SLUG=$(git -C "$HARNESS" remote get-url origin 2>/dev/null | sed -E 's#.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##')
[ -n "$SLUG" ] || exit 0

PRS=$(gh api "repos/$SLUG/pulls?state=open&per_page=100" \
  --jq '.[] | select(.head.ref | startswith("skip-images-")) | .number' 2>/dev/null) || exit 0
for N in $PRS; do
  gh api "repos/$SLUG/pulls/$N/files" --jq '.[] | select(.filename | endswith("skip-images.txt")) | .patch' 2>/dev/null
done | grep '^+[^+]' | sed -e 's/^+//' -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' | sort -u
