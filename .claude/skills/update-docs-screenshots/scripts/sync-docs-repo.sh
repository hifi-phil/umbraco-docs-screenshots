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
# Also fast-forwards origin/main (the fork on GitHub) to match, so the fork doesn't drift further
# behind independently of this one local checkout — a scheduled/cloud run that clones the fork
# fresh instead of reusing this checkout would otherwise see the same staleness the discovery
# heuristic just got fixed for. Push is a plain fast-forward (never --force); if origin/main has
# diverged (e.g. someone committed to the fork's main directly), the push fails loudly rather than
# clobbering it.
#
# Refuses to touch a dirty working tree — never discards uncommitted work. If the `upstream` remote
# is missing (e.g. a scheduled/cloud run that clones the fork fresh every fire never has one), it's
# added automatically rather than treated as fatal — the URL isn't user-specific, it's the same
# umbraco/UmbracoDocs target this skill already hardcodes for the PR base (see
# references/publish-pr.md's `gh pr create --repo umbraco/UmbracoDocs`).

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
  echo "sync-docs-repo.sh: $DOCS has no 'upstream' remote — adding one pointing at umbraco/UmbracoDocs." >&2
  git -C "$DOCS" remote add upstream https://github.com/umbraco/UmbracoDocs.git
fi

git -C "$DOCS" fetch upstream
git -C "$DOCS" checkout main
git -C "$DOCS" pull --ff-only upstream main
git -C "$DOCS" push origin main
