#!/usr/bin/env bash
# Sync $DOCS with upstream/main before anything reads its files (Step 1).
#
# Usage:
#   .../scripts/sync-docs-repo.sh "$DOCS"
#
# Exists because the discovery-fallback scan (Step 3) and targeted/Slack image resolution both
# read files straight out of the $DOCS working tree. If that checkout is behind upstream, a
# screenshot already fixed by a merged PR still looks stale locally, and the discovery heuristic
# picks the same image run after run. Syncing here — before any scan happens — closes that gap.
# (Step 9 also pulls upstream/main right before branching; that's an intentional second check in
# case new commits landed during a long capture run, not a replacement for this one.)
#
# Refuses to touch a dirty working tree — never discards uncommitted work — and requires an
# `upstream` remote to already be configured (same assumption references/publish-pr.md makes).

set -euo pipefail

DOCS="${1:-}"
if [ -z "$DOCS" ] || [ ! -d "$DOCS" ]; then
  echo "sync-docs-repo.sh: \$DOCS not given or not a directory: '$DOCS'" >&2
  exit 1
fi

if [ -n "$(git -C "$DOCS" status --porcelain 2>/dev/null)" ]; then
  echo "sync-docs-repo.sh: $DOCS has uncommitted changes — not syncing. Commit, stash, or clean it up first." >&2
  exit 1
fi

if ! git -C "$DOCS" remote get-url upstream >/dev/null 2>&1; then
  echo "sync-docs-repo.sh: $DOCS has no 'upstream' remote configured (expected to point at umbraco/UmbracoDocs)." >&2
  exit 1
fi

git -C "$DOCS" fetch upstream
git -C "$DOCS" checkout main
git -C "$DOCS" pull --ff-only upstream main
