---
name: update-docs-screenshots
description: >-
  Replaces outdated Umbraco backoffice screenshots in the docs with fresh captures from a running
  local instance, then opens a docs PR. Takes an optional image path to recapture a specific
  screenshot; with no argument it explores the UmbracoDocs repo one article at a time for shots that
  still show the old pre-v14 AngularJS UI and picks one itself; or in "slack" mode it works a shared
  Slack channel as a request queue, processing the next unhandled image link and replying in-thread
  with the resulting PR or error. Either way it uses Playwright to drive the matching demo instance
  (v17 or v18) to that exact backoffice area, recaptures the shot at configurable dimensions, drops
  it in place, and opens a draft docs PR. Use when the user wants to find, refresh, or update
  outdated backoffice screenshots in the documentation, or to work through a Slack channel of
  screenshot requests. Trigger on "update docs screenshots", "find outdated screenshots", "refresh
  backoffice screenshots", "update this screenshot", "recapture <path>.png", "recapture the
  screenshot for <article>", "process the screenshot requests channel", "work the screenshot queue".
---

# Update Docs Screenshots

Repeatable process for replacing outdated Umbraco backoffice screenshots in the docs with fresh
captures of the current ("Bellissima", v14+) UI.

**One run of this skill creates exactly one image PR, then stops.** Take the single image for this
run — given to you or picked in Step 3 — all the way through to an open PR (Step 9), and **end the
run there** — do not find, capture, or PR a second image in the same run. Refreshing another
screenshot requires invoking the skill again. Never batch.

This file carries the step sequence and the decisions at each step. Where a step is pure mechanics
with no judgment call, it's an executable script in `scripts/` rather than bash to retype; where it
needs explanation or heuristics rather than execution, it's a doc in `references/` — each step below
links its own. `references/gotchas.md` is the one worth skimming up front regardless of which step
you're on: known quirks (environment, backoffice-driving, cross-platform) collected from real runs.

## Three modes

The mode is decided by **what the invocation carried**:

| Mode | When | PR guard (Step 2) | Choosing the image (Step 3) |
|---|---|---|---|
| **Discovery** (default) | no argument — how scheduled runs fire | **hard stop** if a screenshot PR is open | full scan, picks a candidate itself |
| **Targeted** | an image path was supplied | **warn only**, run continues | resolves the supplied path |
| **Slack** | invoked as `slack` (or `slack:#channel-name`) | **hard stop** if a screenshot PR is open (also scheduled-style, repeated) | reads a Slack channel as a queue, resolves the next request |

Invocation syntax for each mode, and exactly what stays the same vs. differs across them (the
one-PR-per-run rule, Slack's in-thread reply obligation, scheduling/pacing) are in
`references/modes.md`.

**Running unattended means never pausing mid-run for a human to confirm anything** — a scheduled
routine has no one there to answer. Discovery and Slack mode make their own judgment calls and act
on them autonomously; review happens afterward, via the draft PR (discovery) or the thread reply
(Slack), never by blocking mid-flow waiting on a response. Only targeted mode — inherently
interactive, run from a keyboard with the user right there — may pause to ask something.

> ## ⛔ Playwright only — never claude-in-chrome
> All backoffice interaction — login, navigation, capture — is **Playwright**, including
> route/selector discovery (a throwaway `explore-*.spec.ts`, Step 7). **Never**
> `mcp__claude-in-chrome__*` or `umbraco-chrome-navigation`, for any part of this. Catch yourself
> reaching for a Chrome tab? Write a Playwright spec instead.

## Repos, instances, scope

| | |
|---|---|
| Capture harness (`$HARNESS`) | this repo (contains this skill, `demo/`, `tests/`) — resolved in Step 1 |
| Docs repo (`$DOCS`) | the UmbracoDocs checkout — discovered or asked for in Step 1 |
| v17 instance | `$HARNESS/demo/v17` → `https://localhost:44322/umbraco` |
| v18 instance | `$HARNESS/demo/v18` → `https://localhost:44327/umbraco` |
| Admin login | `admin@admin.com` / `1234567890` (read from env by the helper) |

Paths are **not** hardcoded — `$HARNESS`, `$DOCS`, and `$FORK_OWNER` are established in Step 1 and
used throughout. **Scope is `umbraco-cms` only** (the demo instances are a vanilla CMS) —
`references/scope.md` has exactly what's excluded and why; every mode enforces the same boundary.

## Step 1 — Locate the repos (machine-agnostic)

Resolve `$HARNESS`, `$DOCS`, and `$FORK_OWNER` before anything else — **do not hardcode paths**:

```bash
eval "$(.claude/skills/update-docs-screenshots/scripts/resolve-repos.sh)"
echo "HARNESS=$HARNESS  DOCS=$DOCS  FORK_OWNER=$FORK_OWNER"
```

If `$DOCS` comes back empty, there's no way to guess it safely. Ask the user for the absolute path
(interactive only, per the autonomy note above — in a routine, fail loudly and end the run instead).
See `references/repo-discovery.md` for exactly how each variable is resolved and why.

Use `$HARNESS`, `$DOCS`, and `$FORK_OWNER` in every command below.

## Step 2 — Don't stack PRs (scheduled-run guard)

Count open screenshot PRs from previous runs before doing any work. **Check `command -v gh` first**
— Claude web / a scheduled routine has no `gh` CLI, only `mcp__github__*` tools; see
`references/github-fallback.md` for that path (the exact MCP query and the exit-code logic to apply
by hand):

```bash
.claude/skills/update-docs-screenshots/scripts/check-pr-guard.sh discovery "$FORK_OWNER"   # discovery mode
.claude/skills/update-docs-screenshots/scripts/check-pr-guard.sh targeted "$FORK_OWNER"     # targeted mode
.claude/skills/update-docs-screenshots/scripts/check-pr-guard.sh slack "$FORK_OWNER"        # Slack mode
```

The script gives the open count (and, if any are open, their PR numbers/URLs) and exits:

- **`0`** — proceed to Step 3. In targeted mode this includes the case where the guard tripped but is
  only a warning (printed to stderr) — the user asked for this specific image, so it doesn't stop
  them.
- **`1`** — **discovery and Slack mode.** The guard tripped: report the already-open PR(s) and **end
  the run** — nothing to do until a reviewer merges or closes them. In Slack mode this is a silent
  stop (no message was chosen yet, so there's no thread to reply to).

Screenshot PRs are identified by the `update-screenshot-*` branch prefix used in Step 9 — keep that
prefix so this guard keeps working.

## Step 3 — Choose the image for this run

Exactly one image comes out of this step, along with its `$VERSION` (`17` or `18`), which selects the
instance in Step 4. Follow **one** of the three branches, never more than one:

- **Targeted mode** (an image path was supplied): resolve and validate it with the script — no
  judgment call needed, so this is deterministic. `$ARG` is the path as the user gave it, docs-relative
  or absolute:

  ```bash
  eval "$(.claude/skills/update-docs-screenshots/scripts/resolve-image.sh "$ARG" "$DOCS")"
  echo "IMG=$IMG  REL=$REL  VERSION=$VERSION"
  ```

  A nonzero exit **ends the run** — the script's stderr message already states the specific reason
  (file not found, outside the docs checkout, no demo instance for that version, or out of the
  `umbraco-cms` scope). Never fall back to discovery or substitute a different image on failure. The
  pre-v14 AngularJS check is **not a gate** here — the user picked this image, so recapturing an
  already-current shot is legitimate.
- **Discovery mode** (no path supplied): pick a version to scan first — `$VERSION` isn't known yet
  the way it is in the other two branches (there's no chosen image to derive it from). Default to
  whichever demo instance is already listening (`lsof -nP -iTCP:44322/-iTCP:44327 -sTCP:LISTEN`); if
  neither is up, default to `18`. Then scan `$DOCS/$VERSION/umbraco-cms/**` for the pre-v14
  AngularJS signature and surface one candidate — this needs reading the images and judging them, so
  it isn't scripted; see `references/image-selection.md` for the bounded-shortlist script and the
  detection heuristic. Take the best candidate forward autonomously (per the note above).
- **Slack mode** (invoked as `slack`/`slack:#channel-name`): read the channel as a queue (via MCP
  tool calls — not scriptable), pick the next request by the "last-reply-then-next" algorithm, then
  extract and resolve its image reference the same way targeted mode does
  (`normalize-image-ref.sh` → `resolve-image.sh`). **Read `references/slack-queue.md` before
  running this branch** — it has the channel resolution, the exact queue algorithm, and the one
  departure from targeted mode's failure handling: a `resolve-image.sh` rejection here must be
  followed by an in-thread `❌ Errored: <reason>` reply before ending the run, not just a silent stop.

## Step 4 — Confirm the matching instance is up

The version comes from the chosen image's docs path (`17/...` → v17, `18/...` → v18) — the `$VERSION`
resolved in Step 3. Checking the port, starting the instance if needed, and waiting for it to be
ready is pure mechanics, so it's scripted:

```bash
.claude/skills/update-docs-screenshots/scripts/ensure-instance-up.sh "$VERSION" "$HARNESS"
```

It returns immediately if the port's already listening; otherwise it starts `dotnet run` in the
background (log at `/tmp/umbraco-demo-v<version>.log`, never inside the repo) and blocks until `Now
listening on:` appears or it times out (default 90s — pass a third argument to change it). Transient
`SQLite Error 14: unable to open database file` lines on first boot are expected and already handled
by the script; a nonzero exit means it genuinely timed out — check the log.

## Step 5 — Understand what the image depicts

Find where the image is used and what screen/state it shows, so you know where to navigate. In
targeted and Slack mode the filename is `$(basename "$IMG")` — this grep is how you find the
article(s) that reference it, since you were given the image rather than the article:

```bash
cd "$DOCS"
grep -rn "<image-filename>" --include='*.md' <version>/umbraco-cms/
```

If nothing references it, the image may be orphaned — there's no screen/state to know what to
capture. Targeted mode may ask whether to continue anyway (per the autonomy note above); discovery
just ends the run (a future run tries again); Slack mode replies `❌ Errored: image isn't referenced
by any article — nothing to capture against` and moves on.

Read the surrounding markdown (optionally the rendered page on `docs.umbraco.com`) to note the
target: section, tree node, workspace tab, and whether a menu or modal is open.

## Step 6 — Determine target dimensions

Read the original's pixel size so the capture can match it — command and sizing guidance in
`references/capture-workflow.md`.

## Step 7 — Use Playwright to navigate to that area and recreate the shot

The capture is Playwright-driven end to end: copy the template matching `$VERSION` (there's one per
CMS major — each imports the matching helper version), edit its config block, drive the instance to
the exact screen from Step 5 preferring `umbracoUi` helpers over hand-rolled locators, and capture.
The config knobs, the `umbracoUi` navigation methods, the explore-spec fallback for uncovered
screens, and the run command are all in `references/capture-workflow.md`.

> **These are temporary, single-run artifacts — not part of the repo.** The copied capture spec, any
> `tests/explore-*.spec.ts`, and the staged PNG under `screenshots/` exist only to produce this run's
> image. **Never commit them to the harness repo.** Step 10 deletes them once the docs PR is open.

## Step 8 — Review

Confirm the capture matches the original before moving on — verification steps and the crop/resize
commands are in `references/capture-workflow.md`. If the screen or content is wrong, adjust and
re-run Step 7.

## Step 9 — Replace the asset and open the PR

On a feature branch in the **docs repo**, replace the asset, push, and open a draft PR against
upstream `umbraco/UmbracoDocs` — full commands, the filename-renaming check (a stale version marker
like `-v9` gets stripped and every markdown reference updated to match), and the `gh`/MCP fallback
are all in `references/publish-pr.md`. Two things worth knowing before you open it: the PR is always
a **draft**, and **Slack mode must reply in-thread with the PR URL right away** — don't wait for
Step 10.

## Step 10 — Clean up temp artifacts, then stop (one PR per run)

First, delete this run's temporary artifacts from the harness repo by their **exact filenames, never
a wildcard** (`references/gotchas.md` has why):

```bash
cd "$HARNESS"
rm -f "tests/capture-<name>.spec.ts" "screenshots/<name>.png"
rm -f tests/explore-*.spec.ts   # only if you created one — still name-specific
```

Then check for anything else that shouldn't be committed — environment workarounds (a temporary
Chromium `executablePath`, harmless `dotnet run` Razor diffs — see `references/gotchas.md`) count
too. Revert anything you find that isn't this run's intended change:

```bash
git status --short   # anything left is either PR-worthy (none, in the harness repo) or noise
git checkout -- <any such file>
git status --short   # confirm truly clean before reporting done
```

Then **the run is complete** (per the one-PR-per-run rule at the top of this file — do not loop back
to Step 3). Report the PR (and preview link) and stop. **Slack mode:** double-check the completion
reply actually landed before reporting done — a missing reply means the next invocation picks the
same message again.

The only durable output of a run lives in the **docs repo** (the committed asset on the PR branch).
The harness repo should be left exactly as it was found — clean.

## Gotchas

Instance/port quirks and backoffice-driving lessons learned from real runs are collected in
`references/gotchas.md`. Skim it before Step 4 (instance) and Step 7 (capture), and consult it
directly if something doesn't behave as expected.
