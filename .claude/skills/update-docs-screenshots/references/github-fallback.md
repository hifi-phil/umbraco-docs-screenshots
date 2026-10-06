# `gh` CLI vs MCP fallback (Steps 2 and 9)

The general local-vs-cloud pattern (`command -v gh` → CLI path; no `gh` → `mcp__github__*` tools)
is the `github-ops` skill's — this file only has the two operations specific to this skill that
aren't scriptable on the MCP path (MCP tools are only callable by you, not from a bash script, so
there's no script equivalent — apply the logic by hand).

## Step 2 — counting open screenshot PRs

`scripts/check-pr-guard.sh` is the default path everywhere, including cloud/routine sessions: it
uses `gh api` (REST), because `gh pr list` is GraphQL-backed and GraphQL is blocked from Claude
Code cloud sessions (`403 GitHub GraphQL is not available from Claude Code sessions`). It fails
loudly with exit `3` if `gh` isn't installed and `4` if the API call fails, instead of silently
reporting zero open PRs and bypassing the guard.

**Exit `3` or `4`:** call `mcp__github__search_pull_requests` twice, with
`repo:umbraco/UmbracoDocs is:pr is:open label:ai-screenshot` and
`repo:umbraco/UmbracoDocs is:pr is:open author:<FORK_OWNER>` (the label catches PRs opened from
any account; the author query keeps older unlabelled ones). Merge the two result sets by PR number,
filter for a head branch starting with `update-screenshot-`, and count them. Apply the exact same exit-code
logic the script documents, **against the same limit: 8** (the script's default `MAX_OPEN` — do not
substitute 1, "any", or "at least one"; a handful of open PRs awaiting review is normal):

- **`0`** (proceed) — count is under 8, or targeted mode where being at/over it is only a warning.
- **`1`** (stop) — default mode or explicit Slack mode and the count is **at or over 8**: report the
  already-open PR(s) and end the run.

(Tool name per the current `github-ops` skill; confirm against the live `mcp__github__*` list if it
doesn't match.)

## Step 3 — the rejected-image list (discovery fallback)

`scripts/list-stale-candidates.sh` warns `couldn't list rejected-PR images` when
`scripts/list-rejected-images.sh` fails (no `gh`, or it isn't authenticated). Rebuild the list by
hand: call `mcp__github__search_pull_requests` with
`repo:umbraco/UmbracoDocs is:pr is:closed is:unmerged author:<FORK_OWNER> screenshot in:title`,
then list each result's files (`mcp__github__pull_request_read` with method `get_files`, or `mcp__github__get_pull_request_files` on older servers) and collect the basenames of
every image (and any `previous_filename`). Treat those exactly like `skip-images.txt` entries.

## Step 9 — creating the PR

`gh pr create --repo umbraco/UmbracoDocs --base main --head "$FORK_OWNER:update-screenshot-<name>" --title "[AI] ..." --body "..." --label ai-screenshot`
is the `gh`-CLI path (see `references/publish-pr.md` for the full command in context — note there's
no `--draft` flag: these open ready for review, per team preference).

**No `gh`:** use `mcp__github__create_pull_request` with the same `base`/`head`/`body` values, the
`title` prefixed with `[AI] ` the same way, and `draft: false` (or the field omitted, if the tool
defaults to non-draft). That tool can't set labels, so follow it with `mcp__github__update_issue`
on the new PR number with `labels: ["ai-screenshot"]` (a PR is an issue for labelling purposes).
Everything before it (`git checkout`/`add`/`commit`/`push`) works identically either way — only
these final calls need the fallback.
