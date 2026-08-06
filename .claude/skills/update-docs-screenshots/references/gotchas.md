# Gotchas

- **Stale port `44343`.** `playwright.config.ts` `baseURL`/`process.env.URL` default to a dead
  instance. Always pass `URL=https://localhost:443xx` on the command line **and** navigate with
  absolute URLs in the spec, or the browser silently hits the wrong/dead site while API login still
  "succeeds". The template already reads `process.env.URL` and uses absolute URLs.
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
