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
