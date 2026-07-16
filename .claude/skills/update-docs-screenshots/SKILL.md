---
name: update-docs-screenshots
description: >-
  Finds outdated Umbraco backoffice screenshots in the docs and replaces them with fresh captures
  from a running local instance, then opens a docs PR. Explores the UmbracoDocs repo one article at
  a time for screenshots that still show the old pre-v14 AngularJS UI, uses Playwright to drive the
  matching demo instance (v17 or v18) to that exact backoffice area, recaptures the shot at
  configurable dimensions, drops it in place, and opens a draft docs PR. Use when the
  user wants to find, refresh, or update outdated backoffice screenshots in the documentation.
  Trigger on "update docs screenshots", "find outdated screenshots", "refresh backoffice
  screenshots", "recapture the screenshot for <article>".
---

# Update Docs Screenshots

Repeatable process for replacing outdated Umbraco backoffice screenshots in the docs with fresh
captures of the current ("Bellissima", v14+) UI.

**Process exactly one image at a time, all the way through the PR, before starting the next.** Do
not batch.

## Repos, instances, scope

| | |
|---|---|
| Capture harness (`$HARNESS`) | this repo (contains this skill, `demo/`, `tests/`) — resolved in Step 0 |
| Docs repo (`$DOCS`) | the UmbracoDocs checkout — discovered or asked for in Step 0 |
| v17 instance | `$HARNESS/demo/v17` → `https://localhost:44322/umbraco` |
| v18 instance | `$HARNESS/demo/v18` → `https://localhost:44327/umbraco` |
| Admin login | `admin@admin.com` / `1234567890` (read from env by the helper) |

Paths are **not** hardcoded — the skill is machine-agnostic. `$HARNESS`, `$DOCS`, and `$FORK_OWNER`
are established in Step 0 and used throughout. Ports come from `demo/*/Properties/launchSettings.json`
in this repo, so they are stable across machines.

**Scope is `umbraco-cms` only.** The local demo instances are a vanilla CMS, so only CMS backoffice
screens are reproducible. **Skip everything else — do not treat these as candidates:**

- Cloud: `umbraco-cloud/`, `umbraco-heartcore/`, `umbraco-compose/`, and Deploy-only dialogs
  (Compare / Queue for transfer / Transfer now / Partial restore — these need a Current-vs-Live Cloud
  environment and cannot be reproduced locally).
- Add-on products: `umbraco-commerce/`, `umbraco-deploy/`, `umbraco-engage/`, `umbraco-ui-builder/`,
  `umbraco-workflow/`, and the other non-CMS areas (`umbraco-forms/`, `umbraco-search/`,
  `umbraco-automate/`, `ai-*`).

Effective candidate scope: **`$DOCS/<version>/umbraco-cms/**` only** (version = `17` or `18`).

## Step 0 — Locate the repos (machine-agnostic)

Establish the two repo paths and the fork owner before anything else. **Do not hardcode paths.**

```bash
# Capture harness = the repo that contains this skill (normally your working directory).
HARNESS="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Docs repo: look as a sibling first, then a couple of common roots. A real checkout has a
# .gitbook.yaml at its root and version folders like 17/ and 18/.
DOCS=""
for c in \
  "$(dirname "$HARNESS")"/UmbracoDocs "$(dirname "$HARNESS")"/umbraco-docs \
  "$(dirname "$HARNESS")"/docs "$HOME"/Projects/UmbracoDocs "$HOME"/UmbracoDocs; do
  if [ -f "$c/.gitbook.yaml" ] && [ -d "$c/18" ]; then DOCS="$c"; break; fi
done
# Bounded fallback search if still not found.
if [ -z "$DOCS" ]; then
  DOCS="$(find "$HOME" -maxdepth 5 -name .gitbook.yaml 2>/dev/null \
          | while read -r f; do d="$(dirname "$f")"; \
              git -C "$d" remote -v 2>/dev/null | grep -qi 'UmbracoDocs' && echo "$d" && break; done)"
fi

echo "HARNESS = $HARNESS"
echo "DOCS    = ${DOCS:-NOT FOUND}"
```

- If `$DOCS` is empty, **ask the user for the absolute path to their UmbracoDocs checkout** and use
  that. Do not guess or proceed without it.
- Derive the fork owner (head namespace for the PR) from the docs repo's `origin` remote — never
  assume a username:

```bash
FORK_OWNER="$(gh repo view "$DOCS" --json owner -q .owner.login 2>/dev/null \
  || git -C "$DOCS" remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#')"
echo "FORK_OWNER = $FORK_OWNER"
```

Use `$HARNESS`, `$DOCS`, and `$FORK_OWNER` in every command below.

## Step 1 — Pick a version and confirm the instance is up

The version comes from the candidate's docs path (`17/...` → v17, `18/...` → v18). If starting from a
version rather than a specific image, ask or default to the one whose instance is already running.

Check the port, start the instance if needed, wait for `Now listening on:`:

```bash
lsof -nP -iTCP:44322 -sTCP:LISTEN   # v17
lsof -nP -iTCP:44327 -sTCP:LISTEN   # v18
# if nothing is listening, start it (run in its own terminal / background):
cd "$HARNESS/demo" && dotnet run --project v18
```

On first boot, transient `SQLite Error 14: unable to open database file` lines are expected — wait
for `Now listening on:`.

## Step 2 — Explore the documentation for candidates (one at a time)

This is the core of the skill. Work through `$DOCS/<version>/umbraco-cms/**` only.

1. Read the articles (`.md` / `README.md`) and look at the backoffice screenshots they reference.
   Images live in flat `.gitbook/assets/` folders (or legacy `images/` folders) beside the content.
   Read the PNGs directly to judge them.
2. **Detect the outdated ones by the pre-v14 AngularJS signature:**
   - Circular Umbraco logo, top-left.
   - Horizontal coloured section tabs across the top (Content / Media / Settings / … as tabs).
   - A `Forms` section tab.
   - Old grey tree styling and old workspace chrome.
   Any of these means the shot predates the Bellissima redesign and is outdated for v17/v18.
   (The current UI has a dark left rail of section icons, a light tree panel, and Lit web-component
   workspaces.)
3. **Surface a single best candidate** — the image plus the article that uses it — and confirm with
   the user before capturing. Confirm it is locally reproducible (a CMS backoffice screen, not a
   Cloud/Deploy dialog and not an add-on product).
4. Do not proceed to another image until the current one is finished through its PR (Step 7).

## Step 3 — Understand what the image depicts

Find where the image is used and what screen/state it shows, so you know where to navigate:

```bash
cd "$DOCS"
grep -rn "<image-filename>" --include='*.md' <version>/umbraco-cms/
```

Read the surrounding markdown for the feature, screen, tab, and any specific content/state shown.
Optionally open the rendered page on `docs.umbraco.com` for context. Note the target: which section
(content / media / settings / …), which tree node, which workspace tab, and whether a menu or modal
is open.

## Step 4 — Determine target dimensions

Read the original's pixel size so the capture can match it:

```bash
sips -g pixelWidth -g pixelHeight <path-to-original.png>
```

There is no single docs standard — many tutorial shots are ~800px wide, full-window backoffice shots
run ~1450–1900px, some are retina (2800+). Feed the original's size into the capture config (Step 5).

## Step 5 — Use Playwright to navigate to that area and recreate the shot

The capture is Playwright-driven end to end. Copy the template into `tests/`, edit its clearly-marked
config block, and drive the running instance to the **exact** screen the original showed before
capturing.

```bash
cp "$HARNESS/.claude/skills/update-docs-screenshots/assets/capture-template.spec.ts" \
   "$HARNESS/tests/capture-<name>.spec.ts"
```

Edit the config block at the top of the spec (this is the "make dimensions easy to change" knob):

- `BASE` — instance URL (`https://localhost:44322` v17, `https://localhost:44327` v18).
- `ROUTE` — absolute backoffice path to land on (e.g. `/umbraco/section/content`).
- `OUTPUT` — staging path under `screenshots/`.
- `VIEWPORT` — `{ width, height }` CSS pixels.
- `DEVICE_SCALE_FACTOR` — `1` normally; `2` to match a retina original.
- `MATCH_MODE` — `'viewport'` (final size = viewport × scale) or `'exact'` (post-crop/resize to the
  original's exact pixels in Step 6).
- `CLIP` — optional `{ x, y, width, height }` region, or leave `null` for the whole viewport.
- `navigate(page)` — the navigation steps: expand tree, open a node, switch a workspace tab, open a
  menu/modal — whatever reaches the area from Step 3.

The spec logs in via `umbracoApi` (Management API — no UI typing), `page.goto`s the absolute `ROUTE`,
runs `navigate()`, waits for `umb-app` + `networkidle`, seeds deterministic content via `umbracoApi`
if the shot needs specific data, then screenshots to `OUTPUT`.

Run it (pass `URL` explicitly — see Gotchas):

```bash
cd "$HARNESS"
URL=https://localhost:44327 npx playwright test tests/capture-<name>.spec.ts --project=chromium
```

Working out the routes/selectors is easier interactively first — the
`umbraco-cms-backoffice-skills:umbraco-chrome-navigation` skill drives the live backoffice and reads
the shadow-DOM state, which helps find the right route and the components to wait on.

## Step 6 — Review

- Read the new capture next to the original and confirm it shows the **same screen** in the current
  UI (right section, node, tab, state).
- Verify dimensions: `sips -g pixelWidth -g pixelHeight screenshots/<name>.png`.
- If `MATCH_MODE='exact'` and the size differs, crop/resize to the original's exact W×H:
  ```bash
  sips -c <height> <width> screenshots/<name>.png        # crop to HxW (centered)
  # or: sips -z <height> <width> screenshots/<name>.png   # resize to HxW
  ```
- If the screen or content is wrong, adjust `navigate()` / seeding and re-run Step 5.

## Step 7 — Replace the asset and open the PR

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

## Step 8 — Next image

Only after the current image's PR is open, return to Step 2 for the next candidate — when the user
asks.

## Gotchas

- **Stale port `44343`.** `playwright.config.ts` `baseURL`/`process.env.URL` default to a dead
  instance. Always pass `URL=https://localhost:443xx` on the command line **and** navigate with
  absolute URLs in the spec, or the browser silently hits the wrong/dead site while API login still
  "succeeds". The template already reads `process.env.URL` and uses absolute URLs.
- **Preserve the filename.** Docs reference assets by filename; replacing in place keeps every
  reference valid and avoids editing markdown. Only rename/move if you also add a redirect and update
  references (out of scope for a straight refresh).
- **`umbraco-cms` only.** Skip the cloud set and all add-on products (see Scope). If a shot can only
  exist in Cloud/Deploy or an add-on, it is not a candidate.
- **Self-signed certs.** `ignoreHTTPSErrors: true` is already set in `playwright.config.ts`.
- **Instance must be running** before Playwright runs (Step 1).

## Related skills

- `umbraco-cms-backoffice-skills:umbraco-chrome-navigation` — interactively work out backoffice
  routes/selectors and read live shadow-DOM state.
