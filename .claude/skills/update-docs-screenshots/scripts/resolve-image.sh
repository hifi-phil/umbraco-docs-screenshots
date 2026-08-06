#!/usr/bin/env bash
# Resolve and validate a targeted-mode image path (Step 3, targeted branch).
#
# Usage:
#   eval "$(.../scripts/resolve-image.sh '<arg-path>' "$DOCS")"
#   echo "IMG=$IMG REL=$REL VERSION=$VERSION"
#
# Accepts either a path relative to the docs repo root or an absolute path, so both
# `18/umbraco-cms/.../foo.png` and `/Users/me/Projects/UmbracoDocs/18/umbraco-cms/.../foo.png`
# resolve to the same image. On success prints `export VAR=value` lines. On failure prints a
# specific reason to stderr and exits nonzero — never falls back to discovery mode and never
# substitutes a different image.
#
# Exit codes:
#   0 — resolved and in scope
#   1 — bad arguments
#   2 — file not found (checked as $DOCS-relative and as given)
#   3 — resolved, but outside the docs checkout
#   4 — version is not 17 or 18 (no demo instance for it)
#   5 — not under <version>/umbraco-cms/ (cloud/Deploy/add-on areas can't be captured locally)

set -u

ARG="${1:-}"
DOCS="${2:-}"

if [ -z "$ARG" ] || [ -z "$DOCS" ]; then
  echo "Usage: resolve-image.sh <arg-path> <docs-root>" >&2
  exit 1
fi

IMG=""
if   [ -f "$DOCS/$ARG" ]; then IMG="$DOCS/$ARG"
elif [ -f "$ARG" ];       then IMG="$(cd "$(dirname "$ARG")" && pwd)/$(basename "$ARG")"
fi

if [ -z "$IMG" ]; then
  echo "NOT FOUND: '$ARG' does not exist (checked as \$DOCS-relative and as given). Ask the user for the correct path." >&2
  exit 2
fi

case "$IMG" in
  "$DOCS"/*) ;;
  *)
    echo "OUT OF SCOPE: '$IMG' is not inside the docs checkout ($DOCS)." >&2
    exit 3
    ;;
esac

REL="${IMG#"$DOCS"/}"
VERSION="${REL%%/*}"

case "$VERSION" in
  17|18) ;;
  *)
    echo "OUT OF SCOPE: version '$VERSION' has no demo instance here (only 17 and 18 do)." >&2
    exit 4
    ;;
esac

case "$REL" in
  "$VERSION"/umbraco-cms/*) ;;
  *)
    echo "OUT OF SCOPE: '$REL' is not under <version>/umbraco-cms/ — cloud, Deploy, and add-on-product screens can't be captured locally." >&2
    exit 5
    ;;
esac

printf 'export IMG=%q\n' "$IMG"
printf 'export REL=%q\n' "$REL"
printf 'export VERSION=%q\n' "$VERSION"
