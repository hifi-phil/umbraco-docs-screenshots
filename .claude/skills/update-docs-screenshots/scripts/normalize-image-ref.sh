#!/usr/bin/env bash
# Normalize a Slack-posted image reference into the form resolve-image.sh expects
# (a docs-relative or absolute path) — Step 3, Slack mode.
#
# Usage: normalize-image-ref.sh '<url-or-path-from-a-slack-message>'
#
# Handles:
#   - a GitHub blob URL:   https://github.com/umbraco/UmbracoDocs/blob/main/18/umbraco-cms/.../foo.png
#   - a GitHub raw URL:    https://raw.githubusercontent.com/umbraco/UmbracoDocs/main/18/umbraco-cms/.../foo.png
#   - anything else (a plain docs-relative or absolute path) is passed through unchanged, so
#     resolve-image.sh's own resolution still applies untouched.
#
# Prints the normalized reference on stdout. Never fails — an unrecognized input is echoed as-is
# and left for resolve-image.sh to accept or reject.

set -u

REF="${1:-}"

case "$REF" in
  https://github.com/*/*/blob/*)
    # https://github.com/<owner>/<repo>/blob/<ref>/<path>[?query][#fragment]
    echo "$REF" | sed -E 's#^https://github\.com/[^/]+/[^/]+/blob/[^/]+/##; s/[?#].*$//'
    ;;
  https://raw.githubusercontent.com/*)
    # https://raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>[?query][#fragment]
    echo "$REF" | sed -E 's#^https://raw\.githubusercontent\.com/[^/]+/[^/]+/[^/]+/##; s/[?#].*$//'
    ;;
  *)
    echo "$REF"
    ;;
esac
