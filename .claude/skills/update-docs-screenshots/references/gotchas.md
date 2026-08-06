# Gotchas

- **No single default URL/instance.** `playwright.config.ts`'s `baseURL` is tied to `process.env.URL`
  (no more stale hardcoded port), but the acceptance-test-helpers read `process.env.URL` at
  **import time**, before Playwright applies any project's `use.baseURL` — so passing
  `--project=umbraco-17`/`umbraco-18` alone does *not* set it. Always pass
  `URL=https://localhost:443xx` explicitly on the command line **and** navigate with absolute URLs
  in the spec (the templates already do both).
- **The helper version must match the CMS major.** `@umbraco-cms/acceptance-test-helpers` (17.5.3)
  and the aliased `@umbraco-cms/acceptance-test-helpers-v18` (18.0.2) are both installed — use
  `capture-template.spec.ts` for v17, `capture-template-v18.spec.ts` for v18. Mismatching them isn't
  just a version-pinning nicety: a 17.x helper's locators can genuinely fail to find elements a v18
  backoffice renders differently, and vice versa.
- **`umbracoUi` helpers need `testIdAttribute: 'data-mark'` in `playwright.config.ts`.** They're
  built on Playwright's `getByTestId()`, but the backoffice's own convention is `data-mark`, not
  the `data-testid` Playwright defaults to. Without this config, `umbracoUi.*.goToSection()` and
  most other helper methods silently find nothing and time out — confirmed by dumping a live v18
  dashboard's DOM: 0 `data-testid` attributes anywhere, 18 `data-mark` ones, including
  `section-links` itself. This config is already set; if `umbracoUi` navigation starts failing,
  check this hasn't been removed before assuming the target screen has no helper coverage.
- **Preserve the filename.** Docs reference assets by filename; replacing in place keeps every
  reference valid and avoids editing markdown. Only rename/move if you also add a redirect and update
  references (out of scope for a straight refresh).
- **`umbraco-cms` only.** Skip the cloud set and all add-on products (see Scope in SKILL.md). If a
  shot can only exist in Cloud/Deploy or an add-on, it is not a candidate.
- **Self-signed certs.** `ignoreHTTPSErrors: true` is already set in `playwright.config.ts`.
- **Instance must be running** before Playwright runs (Step 4).

## Backoffice-driving gotchas (learned in real runs)

- **Use native Playwright clicks for tree/router navigation — they are trusted.** A synthetic click
  from `page.evaluate(() => el.click())` is ignored by the SPA router and the tree, so nothing
  navigates. Use `page.getByRole('link'/'button', { name }).click()` instead. (Fine to *walk* the
  shadow DOM in `page.evaluate` to read state — just don't click through it.)
- **Duplicate labels → strict-mode violations.** Several controls share a label (e.g. two `Insert`
  buttons). Scope the locator (`page.locator('#insert-button').getByRole('button', { name: 'Insert' })`)
  or use `.first()`.
- **Modals render in a portal and screenshots can lag.** After opening a modal, wait on a distinctive
  action that only exists once it's live (e.g. its `Submit` button `.waitFor({ state: 'visible' })`)
  then a short `waitForTimeout` to settle, rather than asserting on title text.
- **`Error refreshing access token, performing full re-login.` is normal.** The `umbracoApi` fixture
  logs this on a cold start; it is not a failure.
- **Fresh DB content is unpublished.** Query/preview screens can show empty results ("0 published
  items returned"). If the shot needs populated data, publish content via `umbracoApi` first.
- **Starter Kit template hierarchy (v18):** templates nest under `_Master` (there is no top-level
  `Home` template). Expand `Templates`, then `_Master`, to reach child templates.
- **`umbracoUi` has no top-level `goToSection`/`clickCaretButtonForName`.** These live on
  `UiBaseLocators`, which every domain sub-helper (`content`, `media`, `dataType`, …) extends — call
  them as `umbracoUi.content.goToSection(...)`, not `umbracoUi.goToSection(...)` (the latter throws
  `TypeError: ... is not a function`). Any sub-helper works identically since they all inherit the
  same base methods; which one you pick doesn't need to match the screen.
