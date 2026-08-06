# Capture workflow (Steps 6–8 detail)

## Dimensions (Step 6)

Read the original's pixel size so the capture can match it:

```bash
sips -g pixelWidth -g pixelHeight <path-to-original.png>
```

There is no single docs standard — many tutorial shots are ~800px wide, full-window backoffice shots
run ~1450–1900px, some are retina (2800+). Feed the original's size into the capture config below.

## Capture (Step 7)

The capture is Playwright-driven end to end. Copy the template into `tests/`, edit its clearly-marked
config block, and drive the running instance to the **exact** screen the original showed before
capturing.

```bash
cp "$HARNESS/.claude/skills/update-docs-screenshots/assets/capture-template.spec.ts" \
   "$HARNESS/tests/capture-<name>.spec.ts"
```

> **These are temporary, single-run artifacts — not part of the repo.** The copied capture spec, any
> `tests/explore-*.spec.ts`, and the staged PNG under `screenshots/` exist only to produce this run's
> image. **Never commit them to the harness repo.** Step 10 deletes them once the docs PR is open.

Edit the config block at the top of the spec (this is the "make dimensions easy to change" knob):

- `BASE` — instance URL (`https://localhost:44322` v17, `https://localhost:44327` v18).
- `ROUTE` — absolute backoffice path to land on (e.g. `/umbraco/section/content`).
- `OUTPUT` — staging path under `screenshots/`.
- `VIEWPORT` — `{ width, height }` CSS pixels.
- `DEVICE_SCALE_FACTOR` — `1` normally; `2` to match a retina original.
- `MATCH_MODE` — `'viewport'` (final size = viewport × scale) or `'exact'` (post-crop/resize to the
  original's exact pixels in the Review step).
- `CLIP` — optional `{ x, y, width, height }` region, or leave `null` for the whole viewport.
- `navigate(page)` — the navigation steps: expand tree, open a node, switch a workspace tab, open a
  menu/modal — whatever reaches the area identified in Step 5.

The spec logs in via `umbracoApi` (Management API — no UI typing), `page.goto`s the absolute `ROUTE`,
runs `navigate()`, waits for `umb-app` + `networkidle`, seeds deterministic content via `umbracoApi`
if the shot needs specific data, then screenshots to `OUTPUT`.

Run it (pass `URL` explicitly — see the Gotchas reference):

```bash
cd "$HARNESS"
URL=https://localhost:44327 npx playwright test tests/capture-<name>.spec.ts --project=chromium
```

**Work out routes/selectors with Playwright itself — not claude-in-chrome.** Write a throwaway
`tests/explore-*.spec.ts` that logs in, navigates, and dumps a shadow-DOM-piercing snapshot of
visible actionable elements (walk the DOM, recursing into every `el.shadowRoot`, and print
`tag[role] "label"`). Playwright's own locators already pierce open shadow DOM, so
`getByRole`/`getByText` work across web-component boundaries. Iterate the explore spec until you know
the exact clicks, then bake them into the capture spec. Delete the explore spec afterwards.

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
