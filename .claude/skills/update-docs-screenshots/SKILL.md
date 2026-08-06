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
needs explanation or heuristics rather than execution, it's a doc in `references/`:

| File | What it's for |
|---|---|
| `scripts/resolve-repos.sh` | Step 1 — resolves `$HARNESS`/`$DOCS`/`$FORK_OWNER`, nothing to judge |
| `scripts/check-pr-guard.sh` | Step 2 — counts open screenshot PRs, applies the guard by mode |
| `scripts/resolve-image.sh` | Step 3, targeted/Slack branches — resolves and validates the image path |
| `scripts/normalize-image-ref.sh` | Step 3, Slack branch — turns a pasted GitHub URL into the plain path `resolve-image.sh` expects |
| `scripts/ensure-instance-up.sh` | Step 4 — checks/starts the matching demo instance |
| `scripts/list-stale-candidates.sh` | Step 3, discovery branch — bounds ~3,800 images down to a short prioritized shortlist |
| `references/image-selection.md` | Step 3, discovery branch — the pre-v14 detection heuristic (judgment, not scriptable) |
| `references/slack-queue.md` | Step 3, Slack branch — the channel-as-queue algorithm and reply conventions |
| `references/capture-workflow.md` | Steps 6–8's dimension/config/review mechanics |
| `references/gotchas.md` | Known quirks — skim before Step 4 and Step 7, or on unexpected behavior |

## Three modes

The mode is decided by **what the invocation carried**:

| Mode | When | PR guard (Step 2) | Choosing the image (Step 3) |
|---|---|---|---|
| **Discovery** (default) | no argument — how scheduled runs fire | **hard stop** if a screenshot PR is open | full scan, picks a candidate itself |
| **Targeted** | an image path was supplied | **warn only**, run continues | resolves the supplied path |
| **Slack** | invoked as `slack` (or `slack:#channel-name`) | **hard stop** if a screenshot PR is open (also scheduled-style, repeated) | reads a Slack channel as a queue, resolves the next request |

Targeted mode is for local, interactive use — you already know which image is stale, so the scan is
wasted work and the reviewer-load guard shouldn't block you. Invoke it with a path relative to the
docs repo root, or an absolute one:

```
/update-docs-screenshots 18/umbraco-cms/fundamentals/data/defining-content/images/query-builder.png
/update-docs-screenshots /Users/me/Projects/UmbracoDocs/18/umbraco-cms/.../query-builder.png
```

Slack mode is for a shared request queue — anyone can drop an image link in the channel, and each
invocation works exactly one of them, replying in-thread with the result:

```
/update-docs-screenshots slack                          # defaults to #docs-screenshot-agent
/update-docs-screenshots slack:#some-other-channel
```

The default channel is **`#docs-screenshot-agent`** (private, ID `C0BNAABAFK5` — see
`references/slack-queue.md`). Only pass `slack:#channel-name` to target a different one.

Targeted and Slack mode relax **candidate selection only** — everything else is unchanged, including
the one-PR-per-run rule above. Steps 4–10 are identical across all three modes, except that Slack
mode has one extra obligation layered on top: **whatever step ends the run — success or failure —
reply in the source message's thread before stopping** (Step 3's Slack branch and
`references/slack-queue.md` spell out the exact reply format; don't let a failed run leave the
thread silent, or the next invocation has no way to know that message was already attempted).

Discovery and Slack mode are both designed to run **as a scheduled/repeated routine**. To avoid
overwhelming the docs PR reviewers, successive runs must not stack up open PRs — Step 2 bails out
early if a screenshot PR from a previous run is still open.

**Running unattended means never pausing mid-run for a human to confirm anything** — a scheduled
routine has no one there to answer. Discovery and Slack mode make their own judgment calls and act
on them autonomously; review happens afterward, via the draft PR (discovery) or the thread reply
(Slack), never by blocking mid-flow waiting on a response. Only targeted mode — inherently
interactive, run from a keyboard with the user right there — may pause to ask something.

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

Resolve `$HARNESS`, `$DOCS`, and `$FORK_OWNER` before anything else — **do not hardcode paths**:

```bash
eval "$(.claude/skills/update-docs-screenshots/scripts/resolve-repos.sh)"
echo "HARNESS=$HARNESS  DOCS=$DOCS  FORK_OWNER=$FORK_OWNER"
```

If `$DOCS` comes back empty, there's no way to guess it safely — proceeding without it risks
operating against the wrong repo or failing confusingly later. **In an interactive session, ask the
user** for the absolute path to their UmbracoDocs checkout and re-export `DOCS` yourself. **In an
unattended routine, there's no one to ask** — report the specific failure (repo resolution failed,
here's what was tried) and end the run rather than waiting on a prompt that will never be answered.

Use `$HARNESS`, `$DOCS`, and `$FORK_OWNER` in every command below.

## Step 2 — Don't stack PRs (scheduled-run guard)

Count open screenshot PRs from previous runs before doing any work:

```bash
.claude/skills/update-docs-screenshots/scripts/check-pr-guard.sh discovery "$FORK_OWNER"   # discovery mode
.claude/skills/update-docs-screenshots/scripts/check-pr-guard.sh targeted "$FORK_OWNER"     # targeted mode
.claude/skills/update-docs-screenshots/scripts/check-pr-guard.sh slack "$FORK_OWNER"        # Slack mode
```

The script prints the open count (and, if any are open, their PR numbers/URLs) and exits:

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
  detection heuristic. **Do not pause to confirm the candidate with a human before capturing** —
  this mode is designed for unattended scheduled runs (see below), so there's no one there to
  answer; take the best candidate forward autonomously. The draft PR opened in Step 9 is the
  review checkpoint, not this step — a reviewer can always close it if the candidate was wrong.
- **Slack mode** (invoked as `slack`/`slack:#channel-name`): read the channel as a queue, find the
  next request, and resolve its image reference the same way targeted mode does. This mixes MCP tool
  calls (reading/replying to Slack, which only you can do — not scriptable) with the same
  `resolve-image.sh` script targeted mode uses. Full detail — the channel-resolution step, the exact
  "last-reply-then-next" queue algorithm, and the reply format for both success and failure — is in
  `references/slack-queue.md`; read it before running this branch. Short version:

  1. Resolve the channel (by name if given, else the pending default — see the channel-setup note
     above) and read its history.
  2. Find the newest message that already has a completion reply, then take the **next** message
     after it — not the oldest unreplied message overall (see the reference for why this distinction
     matters). If there's no next message, there's nothing to do: end the run, no reply needed.
  3. Extract the image URL/path from that message's text, normalize it, then resolve it:

     ```bash
     REF="$(.claude/skills/update-docs-screenshots/scripts/normalize-image-ref.sh "$RAW_TEXT")"
     eval "$(.claude/skills/update-docs-screenshots/scripts/resolve-image.sh "$REF" "$DOCS")"
     ```

  4. **A nonzero exit from `resolve-image.sh` does not just end the run here — reply in-thread with
     `❌ Errored: <the script's stderr reason>` first**, so the next invocation knows this message was
     attempted and moves on to the one after it. This is the one place targeted mode's "just end the
     run" instruction isn't sufficient by itself.

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

If nothing references it, the image may be orphaned — refreshing it wouldn't change anything a
reader sees, and without a referencing article there's no screen/state to know what to capture.
**In targeted mode** (interactive, a human is at the keyboard), say so and ask whether to continue
anyway. **In discovery and Slack mode** (unattended, no one to ask), don't pause — end the run with
the reason instead: discovery mode just picked a bad candidate, so report it and stop (a future run
tries again); Slack mode replies `❌ Errored: image isn't referenced by any article — nothing to
capture against` and moves on.

Read the surrounding markdown for the feature, screen, tab, and any specific content/state shown.
Optionally open the rendered page on `docs.umbraco.com` for context. Note the target: which section
(content / media / settings / …), which tree node, which workspace tab, and whether a menu or modal
is open.

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
- **Slack mode:** once `gh pr create` returns the PR URL, reply in-thread to the source message with
  `✅ PR: <pr-url>` right away — don't wait until Step 10. That reply is the durable record the next
  invocation's queue algorithm depends on.

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
**Each invocation handles exactly one image, in all three modes** — in targeted mode that is the
image you were given; in Slack mode that is the one message the queue algorithm picked; refreshing
another means invoking the skill again (with its path, or letting Slack mode pick the next request).

Pacing differs by mode: scheduled discovery and Slack runs refresh the next screenshot only after
this PR is merged/closed (the Step 2 hard stop), so reviewers are never handed a pile of screenshot
PRs at once. Targeted runs are not paced — you chose to open this one.

If you're finishing in Slack mode, double-check the completion reply actually landed before
reporting done — a missing reply means the next invocation will pick the same message again.

The only durable output of a run lives in the **docs repo** (the committed asset on the PR branch).
The harness repo should be left exactly as it was found — clean.

## Gotchas

Instance/port quirks and backoffice-driving lessons learned from real runs are collected in
`references/gotchas.md`. Skim it before Step 4 (instance) and Step 7 (capture), and consult it
directly if something doesn't behave as expected.
