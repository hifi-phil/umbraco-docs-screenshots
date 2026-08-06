#!/usr/bin/env bash
# Resolve $HARNESS, $DOCS, $FORK_OWNER for the update-docs-screenshots skill (Step 1).
#
# Usage:
#   eval "$(.../scripts/resolve-repos.sh)"
#   echo "HARNESS=$HARNESS DOCS=$DOCS FORK_OWNER=$FORK_OWNER"
#
# Prints `export VAR=value` lines on stdout so the caller can eval them directly. DOCS is
# printed empty (never guessed) if no checkout is found — the caller must then ask the user
# for the absolute path rather than proceeding.

HARNESS="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Docs repo: look as a sibling first, then a couple of common roots. A real checkout has a
# .gitbook.yaml at its root and version folders like 17/ and 18/.
DOCS=""
for c in \
  "$(dirname "$HARNESS")"/UmbracoDocs "$(dirname "$HARNESS")"/umbraco-docs \
  "$(dirname "$HARNESS")"/docs "$HOME"/Projects/UmbracoDocs "$HOME"/UmbracoDocs; do
  if [ -f "$c/.gitbook.yaml" ] && [ -d "$c/18" ]; then DOCS="$c"; break; fi
done
# Bounded fallback search if still not found.
if [ -z "$DOCS" ]; then
  DOCS="$(find "$HOME" -maxdepth 5 -name .gitbook.yaml 2>/dev/null \
          | while read -r f; do d="$(dirname "$f")"; \
              git -C "$d" remote -v 2>/dev/null | grep -qi 'UmbracoDocs' && echo "$d" && break; done)"
fi

# Fork owner (PR head namespace), derived from the docs repo's origin remote — never assumed.
FORK_OWNER=""
if [ -n "$DOCS" ]; then
  FORK_OWNER="$(gh repo view "$DOCS" --json owner -q .owner.login 2>/dev/null \
    || git -C "$DOCS" remote get-url origin 2>/dev/null | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#')"
fi

printf 'export HARNESS=%q\n' "$HARNESS"
printf 'export DOCS=%q\n' "$DOCS"
printf 'export FORK_OWNER=%q\n' "$FORK_OWNER"

if [ -z "$DOCS" ]; then
  echo "# DOCS not found — ask the user for the absolute path to their UmbracoDocs checkout." >&2
fi
