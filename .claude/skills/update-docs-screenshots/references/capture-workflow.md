# Capture workflow (Steps 6–8 detail)

## Dimensions (Step 6)

Read the original's pixel size so the capture can match it:

```bash
sips -g pixelWidth -g pixelHeight <path-to-original.png>
```

There is no single docs standard — many tutorial shots are ~800px wide, full-window backoffice shots
run ~1450–1900px, some are retina (2800+). Feed the original's size into the capture config below.

## Capture (Step 7)

The capture is Playwright-driven end to end. There are **two templates, one per CMS major** —
each imports the matching version of `@umbraco-cms/acceptance-test-helpers` (17.5.3 vs. 18.0.2),
since that's what makes the helper's locators match what that major's backoffice actually renders.
Copy whichever matches `$VERSION`, edit its clearly-marked config block, and drive the running
instance to the **exact** screen the original showed before capturing.

```bash
TEMPLATE="capture-template.spec.ts"
[ "$VERSION" = "18" ] && TEMPLATE="capture-template-v18.spec.ts"
cp "$HARNESS/.claude/skills/update-docs-screenshots/assets/$TEMPLATE" \
   "$HARNESS/tests/capture-<name>.spec.ts"
```

> **These are temporary, single-run artifacts — not part of the repo.** The copied capture spec, any
> `tests/explore-*.spec.ts`, and the staged PNG under `screenshots/` exist only to produce this run's
> image. **Never commit them to the harness repo.** Step 10 deletes them once the docs PR is open.

Edit the config block at the top of the spec (this is the "make dimensions easy to change" knob):

- `BASE` — instance URL (`https://localhost:44322` v17, `https://localhost:44327` v18) — already
  defaulted correctly per template, override via the `URL` env var.
- `ROUTE` — absolute backoffice path to land on (e.g. `/umbraco/section/content`).
- `OUTPUT` — staging path under `screenshots/`.
- `VIEWPORT` — `{ width, height }` CSS pixels.
- `DEVICE_SCALE_FACTOR` — `1` normally; `2` to match a retina original. Applied via
  `test.use({ viewport, deviceScaleFactor })` — `page.setViewportSize()` alone can't set this,
  it's a browser-context creation option.
- `MATCH_MODE` — `'viewport'` (final size = viewport × scale) or `'exact'` (post-crop/resize to the
  original's exact pixels in the Review step).
- `CLIP` — optional `{ x, y, width, height }` region, or leave `null` for the whole viewport.
- `navigate(page, umbracoUi)` — the navigation steps: expand tree, open a node, switch a workspace
  tab, open a menu/modal — whatever reaches the area identified in Step 5.

The spec logs in via `umbracoApi` (Management API — no UI typing), `page.goto`s the absolute `ROUTE`,
runs `navigate()`, waits for `umb-app` + `networkidle`, seeds deterministic content via `umbracoApi`
if the shot needs specific data, then screenshots to `OUTPUT`.

Run it (pass `URL` explicitly — see the Gotchas reference):

```bash
cd "$HARNESS"
URL=https://localhost:44327 npx playwright test tests/capture-<name>.spec.ts --project=umbraco-18
```

**Prefer `umbracoUi` helpers over hand-rolled locators inside `navigate()`.** The `umbracoUi`
fixture (from the same helper package) exposes real navigation methods —
`umbracoUi.content.goToSection(ConstantHelper.sections.settings)`,
`umbracoUi.content.clickCaretButtonForName('Templates')` to expand a tree node by label,
`umbracoUi.content.goToContentWithName('Home')`, `umbracoUi.content.clickTabWithName('Info')` to
switch a workspace tab — that wait for visibility and issue real (trusted) clicks, maintained by
the Umbraco team alongside the CMS. `goToSection`/`clickCaretButtonForName` are inherited by every
domain sub-helper (`content`, `media`, `dataType`, `template`, …), so any one of them works — which
sub-helper you call through doesn't have to match the screen you're navigating. This eliminates
most of the need to hand-roll selectors for common navigation. **This only works with
`testIdAttribute: 'data-mark'` set in `playwright.config.ts`** — the helpers are built on
Playwright's `getByTestId()`, but the backoffice's own convention is `data-mark`, not the
`data-testid` Playwright defaults to (verified empirically: a fresh dashboard load has 0
`data-testid` attributes and 18 `data-mark` ones). That config is already set; don't remove it.

**Fall back to a throwaway `tests/explore-*.spec.ts` only for screens with no matching helper
method** — one that logs in, navigates, and dumps a shadow-DOM-piercing snapshot of visible
actionable elements (walk the DOM, recursing into every `el.shadowRoot`, and print
`tag[role] "label"`). Playwright's own locators already pierce open shadow DOM, so
`getByRole`/`getByText` work across web-component boundaries. Iterate the explore spec until you know
the exact clicks, then bake them into the capture spec. Delete the explore spec afterwards. Do not
use claude-in-chrome for this — see the hard rule in SKILL.md.

## Review (Step 8)

- Read the new capture next to the original and confirm it shows the **same screen** in the current
  UI (right section, node, tab, state).
- Verify dimensions: `sips -g pixelWidth -g pixelHeight screenshots/<name>.png`.
- If `MATCH_MODE='exact'` and the size differs, crop/resize to the original's exact W×H:
  ```bash
  sips -c <height> <width> screenshots/<name>.png        # crop to HxW (centered)
  # or: sips -z <height> <width> screenshots/<name>.png   # resize to HxW
  ```
- If the screen or content is wrong, adjust `navigate()` / seeding and re-run the capture.
