# `gh` CLI vs MCP fallback (Steps 2 and 9)

The general local-vs-cloud pattern (`command -v gh` → CLI path; no `gh` → `mcp__github__*` tools)
is the `github-ops` skill's — this file only has the two operations specific to this skill that
aren't scriptable on the MCP path (MCP tools are only callable by you, not from a bash script, so
there's no script equivalent — apply the logic by hand).

## Step 2 — counting open screenshot PRs

`scripts/check-pr-guard.sh` is the `gh`-CLI path; it fails loudly with exit `3` if `gh` isn't
installed (verified: without this it would silently report zero open PRs and bypass the guard on
every cloud run — a real bug this fixes).

**No `gh`:** call `mcp__github__search_pull_requests` with the query
`repo:umbraco/UmbracoDocs is:pr is:open author:<FORK_OWNER>`, filter the results yourself for a
head branch starting with `update-screenshot-`, and count them. Apply the exact same exit-code
logic the script documents, **against the same limit: 8** (the script's default `MAX_OPEN` — do not
substitute 1, "any", or "at least one"; a handful of open PRs awaiting review is normal):

- **`0`** (proceed) — count is under 8, or targeted mode where being at/over it is only a warning.
- **`1`** (stop) — default mode or explicit Slack mode and the count is **at or over 8**: report the
  already-open PR(s) and end the run.

(Tool name per the current `github-ops` skill; confirm against the live `mcp__github__*` list if it
doesn't match.)

## Step 9 — creating the PR

`gh pr create --repo umbraco/UmbracoDocs --base main --head "$FORK_OWNER:update-screenshot-<name>" --draft --title "..." --body "..."`
is the `gh`-CLI path (see `references/publish-pr.md` for the full command in context).

**No `gh`:** use `mcp__github__create_pull_request` with the same `base`/`head`/`title`/`body`/
`draft` values. Everything before it (`git checkout`/`add`/`commit`/`push`) works identically
either way — only this final call needs the fallback.
