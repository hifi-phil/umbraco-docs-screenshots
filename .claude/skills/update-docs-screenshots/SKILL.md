---
name: update-docs-screenshots
description: >-
  Replaces outdated Umbraco backoffice screenshots in the docs with fresh captures from a running
  local instance, then opens a docs PR. Takes an optional image path to recapture a specific
  screenshot; with no argument it explores the UmbracoDocs repo one article at a time for shots that
  still show the old pre-v14 AngularJS UI and picks one itself. Either way it uses Playwright to
  drive the matching demo instance (v17 or v18) to that exact backoffice area, recaptures the shot at
  configurable dimensions, drops it in place, and opens a draft docs PR. Use when the user wants to
  find, refresh, or update outdated backoffice screenshots in the documentation. Trigger on "update
  docs screenshots", "find outdated screenshots", "refresh backoffice screenshots", "update this
  screenshot", "recapture <path>.png", "recapture the screenshot for <article>".
---

# Update Docs Screenshots

Repeatable process for replacing outdated Umbraco backoffice screenshots in the docs with fresh
captures of the current ("Bellissima", v14+) UI.

**One run of this skill creates exactly one image PR, then stops.** Take the single image for this
run — given to you or picked in Step 3 — all the way through to an open PR (Step 9), and **end the
run there** — do not find, capture, or PR a second image in the same run. Refreshing another
screenshot requires invoking the skill again. Never batch.

This file carries the step sequence and the decisions at each step. The mechanical detail behind
several steps — boilerplate scripts, detection heuristics, capture config — lives in `references/`
and is loaded only when that step is reached:

| Reference file | Read it for |
|---|---|
| `references/repo-discovery.md` | Step 1's path-resolution script |
| `references/image-selection.md` | Step 3's targeted-path resolution and discovery-scan detail |
| `references/capture-workflow.md` | Steps 6–8's dimension/config/review mechanics |
| `references/gotchas.md` | Known quirks — skim before Step 4 and Step 7, or on unexpected behavior |

## Two modes

The mode is decided by **whether the invocation carried an image path**:

| Mode | When | PR guard (Step 2) | Choosing the image (Step 3) |
|---|---|---|---|
| **Discovery** (default) | no argument — how scheduled runs fire | **hard stop** if a screenshot PR is open | full scan, picks a candidate itself |
| **Targeted** | an image path was supplied | **warn only**, run continues | resolves the supplied path |

Targeted mode is for local, interactive use — you already know which image is stale, so the scan is
wasted work and the reviewer-load guard shouldn't block you. Invoke it with a path relative to the
docs repo root, or an absolute one:

```
/update-docs-screenshots 18/umbraco-cms/fundamentals/data/defining-content/images/query-builder.png
/update-docs-screenshots /Users/me/Projects/UmbracoDocs/18/umbraco-cms/.../query-builder.png
```

Targeted mode relaxes **candidate selection only** — everything else is unchanged, including the
one-PR-per-run rule above. Steps 4–10 are identical in both modes.

Discovery mode is designed to run **as a scheduled routine**. To avoid overwhelming the docs PR
reviewers, successive scheduled runs must not stack up open PRs — Step 2 bails out early if a
screenshot PR from a previous run is still open.

> ## ⛔ Playwright only — never claude-in-chrome
> All backoffice interaction (logging in, navigating sections, expanding the tree, opening
> workspaces/modals, and capturing) is done with **Playwright**. **Do NOT use the
> `mcp__claude-in-chrome__*` tools or the `umbraco-chrome-navigation` skill** for any part of this —
> not for exploration, not for capture. Route/selector discovery is a throwaway Playwright
> `explore-*.spec.ts` (Step 7). If you catch yourself about to open a Chrome tab, stop and write a
> Playwright spec instead.

## Repos, instances, scope

| | |
|---|---|
| Capture harness (`$HARNESS`) | this repo (contains this skill, `demo/`, `tests/`) — resolved in Step 1 |
| Docs repo (`$DOCS`) | the UmbracoDocs checkout — discovered or asked for in Step 1 |
| v17 instance | `$HARNESS/demo/v17` → `https://localhost:44322/umbraco` |
| v18 instance | `$HARNESS/demo/v18` → `https://localhost:44327/umbraco` |
| Admin login | `admin@admin.com` / `1234567890` (read from env by the helper) |

Paths are **not** hardcoded — the skill is machine-agnostic. `$HARNESS`, `$DOCS`, and `$FORK_OWNER`
are established in Step 1 and used throughout.

**Scope is `umbraco-cms` only.** The local demo instances are a vanilla CMS, so only CMS backoffice
screens are reproducible. **Skip everything else — do not treat these as candidates:**

- Cloud: `umbraco-cloud/`, `umbraco-heartcore/`, `umbraco-compose/`, and Deploy-only dialogs
  (Compare / Queue for transfer / Transfer now / Partial restore — these need a Current-vs-Live Cloud
  environment and cannot be reproduced locally).
- Add-on products: `umbraco-commerce/`, `umbraco-deploy/`, `umbraco-engage/`, `umbraco-ui-builder/`,
  `umbraco-workflow/`, and the other non-CMS areas (`umbraco-forms/`, `umbraco-search/`,
  `umbraco-automate/`, `ai-*`).

Effective candidate scope: **`$DOCS/<version>/umbraco-cms/**` only** (version = `17` or `18`).

## Step 1 — Locate the repos (machine-agnostic)

Resolve `$HARNESS`, `$DOCS`, and `$FORK_OWNER` before anything else — **do not hardcode paths**. Run
the resolution script in `references/repo-discovery.md`.

If `$DOCS` comes back empty, **ask the user for the absolute path to their UmbracoDocs checkout**.
Do not guess or proceed without it.

Use `$HARNESS`, `$DOCS`, and `$FORK_OWNER` in every command below.

## Step 2 — Don't stack PRs (scheduled-run guard)

Check how many screenshot PRs from previous runs are still open before doing any work:

```bash
MAX_OPEN=1   # max concurrent open screenshot PRs from this skill; raise only if reviewers can absorb more
OPEN=$(gh pr list --repo umbraco/UmbracoDocs --author "$FORK_OWNER" --state open \
        --json number,headRefName \
        -q '[.[] | select(.headRefName | startswith("update-screenshot-"))] | length')
echo "Open screenshot PRs: $OPEN (limit $MAX_OPEN)"
```

Screenshot PRs are identified by the `update-screenshot-*` branch prefix used in Step 9 — keep that
prefix so this guard keeps working.

- **Discovery mode:** if `OPEN >= MAX_OPEN`, report the already-open PR(s) and **end the run**
  (nothing to do until a reviewer merges or closes them). Otherwise continue to Step 3.
- **Targeted mode:** run the same check for information only. If `OPEN >= MAX_OPEN`, list the open
  PR(s) and warn that this run will stack another screenshot PR on top of them — then **continue** to
  Step 3. The user asked for this specific image, so the guard does not stop them.

## Step 3 — Choose the image for this run

Exactly one image comes out of this step, along with its `$VERSION` (`17` or `18`), which selects the
instance in Step 4. Follow **one** of the two branches, never both — see `references/image-selection.md`
for the full detail of each:

- **Targeted mode** (an image path was supplied): resolve and validate it. Any validation failure
  **ends the run** with the specific reason; never fall back to discovery or substitute a different
  image. The pre-v14 AngularJS check is **not a gate** here — the user picked this image, so
  recapturing an already-current shot is legitimate.
- **Discovery mode** (no path supplied): scan `$DOCS/<version>/umbraco-cms/**` for the pre-v14
  AngularJS signature and surface one candidate. Confirm it with the user before capturing.

## Step 4 — Confirm the matching instance is up

The version comes from the chosen image's docs path (`17/...` → v17, `18/...` → v18) — the `$VERSION`
resolved in Step 3.

Check the port, start the instance if needed, wait for `Now listening on:`:

```bash
lsof -nP -iTCP:44322 -sTCP:LISTEN   # v17
lsof -nP -iTCP:44327 -sTCP:LISTEN   # v18
# if nothing is listening, start it (run in its own terminal / background):
cd "$HARNESS/demo" && dotnet run --project v18
```

On first boot, transient `SQLite Error 14: unable to open database file` lines are expected — wait
for `Now listening on:`.

## Step 5 — Understand what the image depicts

Find where the image is used and what screen/state it shows, so you know where to navigate. In
targeted mode the filename is `$(basename "$IMG")` — this grep is how you find the article(s) that
reference it, since the user gave you the image rather than the article:

```bash
cd "$DOCS"
grep -rn "<image-filename>" --include='*.md' <version>/umbraco-cms/
```

If nothing references it, say so — the image may be orphaned, and refreshing it changes nothing on
the site. Ask whether to continue.

Read the surrounding markdown for the feature, screen, tab, and any specific content/state shown.
Optionally open the rendered page on `docs.umbraco.com` for context. Note the target: which section
(content / media / settings / …), which tree node, which workspace tab, and whether a menu or modal
is open.

## Step 6 — Determine target dimensions

Read the original's pixel size so the capture can match it — command and sizing guidance in
`references/capture-workflow.md`.

## Step 7 — Use Playwright to navigate to that area and recreate the shot

The capture is Playwright-driven end to end: copy the template, edit its config block, drive the
instance to the exact screen from Step 5, and capture. The config knobs, the explore-spec technique
for finding routes/selectors, and the run command are all in `references/capture-workflow.md`.

> **These are temporary, single-run artifacts — not part of the repo.** The copied capture spec, any
> `tests/explore-*.spec.ts`, and the staged PNG under `screenshots/` exist only to produce this run's
> image. **Never commit them to the harness repo.** Step 10 deletes them once the docs PR is open.

## Step 8 — Review

Confirm the capture matches the original before moving on — verification steps and the crop/resize
commands are in `references/capture-workflow.md`. If the screen or content is wrong, adjust and
re-run Step 7.

## Step 9 — Replace the asset and open the PR

In the **docs repo**, on a feature branch, replace the asset in place (keep the exact path and
filename so every `.md` reference keeps working), then push and open a draft PR:

```bash
cd "$DOCS"
git checkout main && git pull upstream main
git checkout -b update-screenshot-<name>
cp "$HARNESS/screenshots/<name>.png" <version>/umbraco-cms/.../<original-filename>.png
git add <path-to-asset>
git commit -m "Update <article> backoffice screenshot for v<version>"
git push origin update-screenshot-<name>          # origin = the fork ($FORK_OWNER)
gh pr create --repo umbraco/UmbracoDocs --base main --head "$FORK_OWNER:update-screenshot-<name>" --draft \
  --title "Update <article> backoffice screenshot" --body "Refreshed outdated pre-v14 screenshot for v<version>."
```

Notes:
- The branch lives on the fork (`origin`); the PR is opened against upstream `umbraco/UmbracoDocs`,
  base branch `main`. Keep it a **draft** unless the user says otherwise.
- Because only an image is being replaced (no markdown/prose changes), Vale has nothing to lint. If a
  future run also edits `.md`, run `vale <changed.md>` and fix any errors before pushing.
- GitBook builds a preview per push; the PR checks include a `docs.umbraco.com` revision link — return
  it plus the PR URL to the user once it's built.

## Step 10 — Clean up temp artifacts, then stop (one PR per run)

First, delete this run's temporary artifacts from the harness repo — they are not part of it and must
never be committed:

```bash
cd "$HARNESS"
rm -f tests/capture-<name>.spec.ts tests/explore-*.spec.ts screenshots/<name>.png
git status --short   # confirm the harness repo is clean
```

Then **the run is complete.** Report the PR (and preview link) to the user and stop.
Do not loop back to Step 3, do not scan for more candidates, and do not open a second PR in this run.
**Each invocation handles exactly one image, in both modes** — in targeted mode that is the image you
were given; refreshing another means invoking the skill again with its path.

Pacing differs by mode: scheduled discovery runs refresh the next screenshot only after this PR is
merged/closed (the Step 2 hard stop), so reviewers are never handed a pile of screenshot PRs at
once. Targeted runs are not paced — you chose to open this one.

The only durable output of a run lives in the **docs repo** (the committed asset on the PR branch).
The harness repo should be left exactly as it was found — clean.

## Gotchas

Instance/port quirks and backoffice-driving lessons learned from real runs are collected in
`references/gotchas.md`. Skim it before Step 4 (instance) and Step 7 (capture), and consult it
directly if something doesn't behave as expected.
