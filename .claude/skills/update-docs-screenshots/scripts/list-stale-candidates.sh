#!/usr/bin/env bash
# List a bounded, prioritized shortlist of candidate images for discovery mode (Step 3).
#
# Usage: list-stale-candidates.sh <17|18> <docs-root> [limit]
#
# Discovery mode's job is to find ONE stale screenshot, not achieve exhaustive coverage in a
# single run — reading all ~3,800 images across both CMS majors is neither feasible nor
# necessary. This gives a short, prioritized list to actually open/read instead of the whole tree:
#
#   1. Images whose filename carries an OLD version marker (v1–v13) — the highest-hit-rate signal
#      for staleness found by testing against the real repo (e.g. Content-Picker2-DataType-v10.png,
#      query-builder-v9.png are genuinely untouched since 2023 despite unrelated recent commits).
#   2. Everything else (no version marker at all — ~88% of all images), in random order so
#      repeated runs sample different parts of this bulk pool rather than always hitting the same
#      alphabetically-first files.
#
# Images whose filename already carries the CURRENT version's own marker (v<version>/-<version>)
# are excluded entirely — filename evidence (the-section-menu-18.png, generic-tab-18.png, both
# confirmed already-current UI) shows these are already-refreshed shots.
#
# NOTE: git commit dates were tried first and rejected — a file's last-commit date often reflects
# an unrelated bulk restructuring/GitBook-sync commit, not a real content update (verified: a
# genuinely stale v10-suffixed file's last "real" content commit was in 2023, despite a 2026
# last-commit date from an unrelated docs-infra commit). Filename markers, while incomplete, don't
# have this false-recency problem.
#
# Output: one docs-relative path per line, capped to [limit] (default 20).

set -u

VERSION="${1:-}"
DOCS="${2:-}"
LIMIT="${3:-20}"

case "$VERSION" in
  17|18) ;;
  *)
    echo "Usage: list-stale-candidates.sh <17|18> <docs-root> [limit]" >&2
    exit 1
    ;;
esac
if [ -z "$DOCS" ] || [ ! -d "$DOCS/$VERSION/umbraco-cms" ]; then
  echo "Usage: list-stale-candidates.sh <17|18> <docs-root> [limit]" >&2
  exit 1
fi

cd "$DOCS/$VERSION/umbraco-cms" || exit 1

ALL=$(find . \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null)

# Exclude anything already marked with the CURRENT version — treat as already refreshed.
CANDIDATES=$(echo "$ALL" | grep -Eiv "(v${VERSION}|[-_]${VERSION})\.(png|jpe?g)\$")

OLD_MARKED=$(echo "$CANDIDATES" | grep -Ei 'v(1[0-3]|[1-9])[^0-9]*\.(png|jpe?g)$')
UNMARKED=$(echo "$CANDIDATES" | grep -Eiv 'v(1[0-3]|[1-9])[^0-9]*\.(png|jpe?g)$')

{
  echo "$OLD_MARKED"
  echo "$UNMARKED" | sort -R
} | grep -v '^$' | sed "s#^\./#${VERSION}/umbraco-cms/#" | head -n "$LIMIT"
