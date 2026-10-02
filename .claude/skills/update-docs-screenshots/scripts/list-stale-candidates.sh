#!/usr/bin/env bash
# List a bounded, prioritized shortlist of candidate images for discovery mode (Step 3).
#
# Usage: list-stale-candidates.sh <17|18> <docs-root> [limit] [fork-owner]
#
# Always excludes basenames in ../skip-images.txt. With [fork-owner], also excludes images from
# that fork's closed-unmerged screenshot PRs (scripts/list-rejected-images.sh); if that lookup
# fails it warns on stderr and carries on with only the skip file.
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
FORK_OWNER="${4:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Scan both in-scope product areas. umbraco-forms is optional — older docs checkouts or a
# harness without Forms installed simply won't have images there, so its absence isn't an error.
ALL=""
for AREA in umbraco-cms umbraco-forms; do
  AREA_DIR="$DOCS/$VERSION/$AREA"
  [ -d "$AREA_DIR" ] || continue
  AREA_FILES=$(cd "$AREA_DIR" && find . \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null | sed "s#^\./#${AREA}/#")
  ALL="$ALL
$AREA_FILES"
done
ALL=$(echo "$ALL" | grep -v '^$')

# Exclude anything already marked with the CURRENT version — treat as already refreshed.
CANDIDATES=$(echo "$ALL" | grep -Eiv "(v${VERSION}|[-_]${VERSION})\.(png|jpe?g)\$")

# Exclude images a reviewer has already turned down: the hand-kept skip file, plus (if a fork
# owner was given) every image from a closed-unmerged screenshot PR.
SKIP=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$SCRIPT_DIR/../skip-images.txt" 2>/dev/null)
if [ -n "$FORK_OWNER" ]; then
  if REJECTED=$("$SCRIPT_DIR/list-rejected-images.sh" "$FORK_OWNER"); then
    SKIP="$SKIP
$REJECTED"
  else
    echo "WARN: couldn't list rejected-PR images — excluding skip-images.txt entries only." >&2
  fi
fi
SKIP=$(echo "$SKIP" | grep -v '^$')
if [ -n "$SKIP" ]; then
  CANDIDATES=$(echo "$CANDIDATES" | awk -F/ 'NR==FNR { skip[$0]; next } !($NF in skip)' <(echo "$SKIP") -)
fi

OLD_MARKED=$(echo "$CANDIDATES" | grep -Ei 'v(1[0-3]|[1-9])[^0-9]*\.(png|jpe?g)$')
UNMARKED=$(echo "$CANDIDATES" | grep -Eiv 'v(1[0-3]|[1-9])[^0-9]*\.(png|jpe?g)$')

{
  echo "$OLD_MARKED"
  echo "$UNMARKED" | sort -R
} | grep -v '^$' | sed "s#^#${VERSION}/#" | head -n "$LIMIT"
