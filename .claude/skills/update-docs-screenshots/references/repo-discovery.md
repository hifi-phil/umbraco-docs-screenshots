# Repo discovery (Step 1 detail)

`scripts/resolve-repos.sh` is the executable source of truth for this — run it (see SKILL.md Step
1), don't retype its logic. This file explains what it does and why, for when the resolution
doesn't behave as expected.

`$HARNESS` is just `git rev-parse --show-toplevel` (or `pwd` as a fallback) — the repo containing
this skill, normally the current working directory.

`$DOCS` is found by checking a few common locations for a real UmbracoDocs checkout — identified by
a `.gitbook.yaml` at its root plus a `18/` version folder — first as a sibling of `$HARNESS`
(`UmbracoDocs`, `umbraco-docs`, `docs`), then under `$HOME/Projects` and `$HOME` directly. If none of
those match, it falls back to a bounded `find "$HOME" -maxdepth 5 -name .gitbook.yaml` search,
filtered to checkouts whose `origin` remote mentions `UmbracoDocs`.

**If `$DOCS` comes back empty, the script does not guess further.** Ask the user for the absolute
path to their UmbracoDocs checkout and use that — do not proceed without it.

`$FORK_OWNER` (the PR head namespace) is read from the docs repo's `origin` remote via `gh repo view`
(falling back to parsing the remote URL directly) — never assumed from a username.

## Keeping `$DOCS` fresh

`scripts/sync-docs-repo.sh "$DOCS"` (run right after resolution, still Step 1) fetches `upstream`,
checks out `main`, and fast-forwards it to `upstream/main`. This runs **before** Step 3 touches any
file in `$DOCS` on purpose: the discovery-fallback scan and image resolution both read straight out
of the working tree, so a checkout that's behind upstream makes a screenshot someone already fixed
(merged PR, never pulled locally) look stale again — the discovery heuristic then keeps re-nominating
the same already-fixed image every run. Syncing first closes that gap.

It refuses to run against a dirty working tree (won't discard uncommitted work) and requires an
`upstream` remote pointing at `umbraco/UmbracoDocs` to already exist — the same assumption
`references/publish-pr.md`'s Step 9 pull makes. Step 9 pulls `upstream/main` again right before
branching; that's an intentional second check for commits landing mid-run, not a substitute for
syncing here.

It also fast-forwards `origin/main` (the fork on GitHub) to match, so the fork itself doesn't drift
further behind independently of any one local checkout — a scheduled/cloud run that clones the fork
fresh instead of reusing this checkout would otherwise hit the same staleness bug again. That push
is a plain fast-forward (never `--force`); if `origin/main` has diverged, it fails loudly instead of
overwriting whatever's there.
