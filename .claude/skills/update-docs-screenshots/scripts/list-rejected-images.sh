#!/usr/bin/env bash
# Print the basenames of images that an earlier screenshot PR touched and a reviewer then closed
# without merging. Discovery mode excludes these so the same rejected image isn't re-captured
# every day.
#
# Usage: list-rejected-images.sh <fork-owner>
#
# Why: list-stale-candidates.sh ranks old-version-marked files first in a fixed order, so a
# rejected image (e.g. sensitive-data-user-group-v8.png, closed with "Don't update this
# screenshot") came back at the top of every run. Four routine runs in a row re-captured it, hit
# the old PR, abandoned it, and then stalled on a cleanup permission prompt.
#
# Any closed-unmerged screenshot PR counts, not only explicit rejections — a human has already
# looked at that image. Targeted and Slack-sourced runs don't use this list, so a person can still
# request one of these images explicitly.
#
# Uses REST (search + pulls/<n>/files), not GraphQL, which is blocked from Claude Code cloud
# sessions. Exit 3 if gh is missing, 4 if an API call fails — callers treat both as "no list".

set -u

FORK_OWNER="${1:-}"
if [ -z "$FORK_OWNER" ]; then
  echo "Usage: list-rejected-images.sh <fork-owner>" >&2
  exit 2
fi
command -v gh >/dev/null 2>&1 || { echo "gh CLI not found" >&2; exit 3; }

Q="repo:umbraco/UmbracoDocs is:pr is:closed is:unmerged author:$FORK_OWNER screenshot in:title"
PRS=$(gh api -X GET search/issues -f q="$Q" -f per_page=100 --jq '.items[].number') || exit 4

for N in $PRS; do
  gh api --paginate "repos/umbraco/UmbracoDocs/pulls/$N/files?per_page=100" \
    --jq '.[] | .filename, (.previous_filename // empty)' || exit 4
done | grep -Ei '\.(png|jpe?g|gif|webp)$' | sed 's#.*/##' | sort -u
