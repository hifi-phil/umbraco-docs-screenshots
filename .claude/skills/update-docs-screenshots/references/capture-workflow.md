# Capture workflow (Steps 6–8 detail)

## Dimensions (Step 6)

Read the original's pixel size so the capture can match it. `sips` is **macOS-only** — it doesn't
exist on the Linux containers a cloud/routine run uses. Read PNGs cross-platform instead: a PNG's
width/height live at a fixed byte offset in its IHDR chunk, so a tiny Node snippet (Node's already a
hard dependency here) reads it with no external tool at all — verified against a real file, matches
`sips` exactly:

```bash
node -e "
const buf = require('fs').readFileSync(process.argv[1]);
console.log('width:', buf.readUInt32BE(16), 'height:', buf.readUInt32BE(20));
" <path-to-original.png>
```

For a non-PNG original (occasionally `.jpg`), `file <path>` reports dimensions in its output on both
macOS and Linux (verified: `..., 1560x810, components 3`) — parse the `WxH` out of that instead.

There is no single docs standard — many tutorial shots are ~800px wide, full-window backoffice shots
run ~1450–1900px, some are retina (2800+). Feed the original's size into the capture config below.

**If the original has hand-added annotations** (arrows/callout labels pointing into extra margin
around the actual UI, added in an external image editor after the raw screenshot was taken — a real
example: a docs image with red arrows in blank space labeling "Preset crops"/"Focal Point picker"),
its full canvas size includes that annotation margin, which a raw Playwright capture will never
reproduce. Match the **functional content area's** proportions in that case, not the padded
annotated canvas — recreating the original's exact pixel dimensions isn't the actual goal, showing
the same UI content is.

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
  original's exact pixels in the Review step — **macOS-only**, since it needs `sips`; see Review).
- `CLIP` — optional `{ x, y, width, height }` region, or leave `null` for the whole viewport.
  **Prefer computing `VIEWPORT` (or `CLIP`) directly from Step 6's target dimensions** — set it to
  literally equal the target size (accounting for `DEVICE_SCALE_FACTOR`) so Playwright's own
  screenshot produces the right size natively, with no post-processing step or platform-specific
  tool needed at all. This is the cross-platform-safe default; don't guess at a crop region and
  fix it up afterward — a mismatched guess is how a real run ended up with a capture cut off short
  of what the original showed (PR #8305: original 944×720, capture came out 970×460, missing a
  metadata panel the original included).
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
  UI (right section, node, tab, state) — and just as importantly, that **nothing the original
  showed is missing or cut off** in the new one (a metadata panel, a lower section of a form, …).
  Matching numeric dimensions doesn't guarantee this — a real run's capture had the "right"
  dimensions for its `CLIP` region but that region itself was too short, silently cropping out
  content the original included. Read the image, don't just check its size.
- Verify dimensions (same Node/`file` approach as Step 6 — `sips` is macOS-only):
  ```bash
  node -e "const b=require('fs').readFileSync(process.argv[1]);console.log(b.readUInt32BE(16), b.readUInt32BE(20))" screenshots/<name>.png
  ```
- If the size or content is wrong, **fix it at the source and recapture** — adjust `VIEWPORT`/`CLIP`
  (sized from Step 6's target, per Step 7) or `navigate()`/seeding, then re-run. This is the
  cross-platform-safe path.
- **macOS only:** `sips -c <height> <width> screenshots/<name>.png` (crop) / `sips -z <height>
  <width> screenshots/<name>.png` (resize) can post-process `MATCH_MODE='exact'` output — but
  recapturing with the right `VIEWPORT`/`CLIP` is preferred even here, since it doesn't risk
  cropping into content the way a guessed post-hoc crop region can.
