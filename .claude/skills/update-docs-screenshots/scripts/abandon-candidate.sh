#!/usr/bin/env bash
# Drop a candidate the run decided not to ship: return the docs checkout to main and delete the
# local update-screenshot-* branch (Step 9's "abandoning a candidate").
#
# Usage: abandon-candidate.sh <docs-root> <update-screenshot-branch> [untracked-file ...]
#
# Why this is a script: in unattended routine runs, `cd "$DOCS" && git checkout main && git branch
# -D ...` raised a permission prompt every time (a cd before a git command is always flagged, and
# so is branch deletion). Nobody answers prompts in a scheduled run, so four runs stalled there.
# This script uses `git -C`, and the scripts directory is allowlisted in .claude/settings.json, so
# cleanup runs without asking.
#
# `checkout -f` is safe here: sync-docs-repo.sh refuses to start a run on a dirty checkout, so any
# uncommitted change at this point was made by this run. Untracked files are removed only when you
# name them exactly (paths relative to <docs-root>), never with a wildcard or `git clean`.

set -u

DOCS="${1:-}"
BRANCH="${2:-}"
shift 2 2>/dev/null || true

if [ -z "$DOCS" ] || [ ! -d "$DOCS/.git" ] || [ -z "$BRANCH" ]; then
  echo "Usage: abandon-candidate.sh <docs-root> <update-screenshot-branch> [untracked-file ...]" >&2
  exit 2
fi
case "$BRANCH" in
  update-screenshot-*) ;;
  *) echo "Refusing: '$BRANCH' isn't an update-screenshot-* branch." >&2; exit 2 ;;
esac

git -C "$DOCS" checkout -q -f main || exit 1
for f in "$@"; do
  if [ -n "$(git -C "$DOCS" ls-files --others --exclude-standard -- "$f")" ]; then
    rm -f -- "$DOCS/$f"
  fi
done
if git -C "$DOCS" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git -C "$DOCS" branch -D "$BRANCH" || exit 1
fi

LEFT=$(git -C "$DOCS" status --porcelain)
if [ -n "$LEFT" ]; then
  echo "Docs checkout still not clean — pass these to this script by exact path, or report them:" >&2
  echo "$LEFT" >&2
  exit 1
fi
echo "Abandoned $BRANCH; $DOCS is clean on main."
