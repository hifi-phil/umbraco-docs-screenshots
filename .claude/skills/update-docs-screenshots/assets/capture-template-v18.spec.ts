import { test, UiHelpers, ConstantHelper } from '@umbraco-cms/acceptance-test-helpers-v18';
import { expect } from '@playwright/test';
import { execFileSync } from 'node:child_process';

/**
 * Capture template for refreshing an outdated docs backoffice screenshot — v18 variant.
 * Use capture-template.spec.ts instead for a v17 target (each imports the helper version
 * that matches its CMS major — see references/repo-discovery.md).
 *
 * Copy this file to tests/capture-<name>.spec.ts, edit the CONFIG block and the
 * navigate() function, then run it against the matching instance:
 *
 *   URL=https://localhost:44327 npx playwright test tests/capture-<name>.spec.ts --project=umbraco-18
 *
 * Login is via the Management API (umbracoApi fixture); the screenshot is a plain
 * Playwright capture of the live backoffice.
 *
 * NOTE: navigation uses absolute URLs from process.env.URL on purpose — page.goto() with a
 * relative path resolves against the project's baseURL, which only matches if you passed the
 * matching --project. Absolute URLs sidestep that entirely. Always pass URL=https://localhost:443xx
 * on the CLI regardless.
 */

// ─── CONFIG ──────────────────────────────────────────────────────────────────
// Instance base URL. v17 → 44322, v18 → 44327. Overridden by the URL env var.
const BASE = process.env.URL ?? 'https://localhost:44327';

// Absolute backoffice path to land on before navigate() runs.
const ROUTE = '/umbraco/section/content';

// Where the capture is written (staging), relative to repo root.
const OUTPUT = 'screenshots/capture.png';

// Viewport in CSS pixels. Final image = width×height × DEVICE_SCALE_FACTOR (unless CLIP is set).
const VIEWPORT = { width: 1280, height: 720 };

// 1 = normal, 2 = retina (matches a 2× original).
const DEVICE_SCALE_FACTOR = 1;

// 'viewport' → final size is the viewport (× scale).
// 'exact'    → after capture, crop/resize with sips to TARGET exactly (set TARGET below).
const MATCH_MODE: 'viewport' | 'exact' = 'viewport';

// Only used when MATCH_MODE === 'exact'. The original docs image's pixel size.
const TARGET = { width: 1280, height: 720 };
// 'crop' keeps pixels 1:1 and trims (sips -c); 'resize' scales to fit (sips -z).
const EXACT_STRATEGY: 'crop' | 'resize' = 'crop';

// Optional capture region within the viewport, or null for the whole viewport.
const CLIP: { x: number; y: number; width: number; height: number } | null = null;

/**
 * Drive the backoffice to the exact area the original screenshot showed.
 *
 * Prefer `umbracoUi` helpers over raw locators wherever one exists for the target screen — they
 * issue real (trusted) Playwright clicks after waiting for visibility, and the Umbraco team
 * maintains them alongside the CMS, so they track UI changes across releases better than
 * hand-rolled selectors do. `goToSection`/`clickCaretButtonForName` (generic tree/section nav)
 * are inherited by every domain sub-helper, so any of them works — `.content.` below is just a
 * convenient default, not a requirement:
 *
 *   await umbracoUi.content.goToSection(ConstantHelper.sections.settings);
 *   await umbracoUi.content.clickCaretButtonForName('Templates');  // expand a tree node by label
 *   await umbracoUi.content.goToContentWithName('Home');           // open a content node by name
 *   await umbracoUi.content.clickTabWithName('Info');    // switch a workspace tab (content/library only)
 *
 * Fall back to raw Playwright (`page.getByRole(...)`, `page.locator(...)`) only for screens with
 * no matching helper method — a throwaway tests/explore-*.spec.ts (see
 * references/capture-workflow.md) is still the way to find those selectors.
 *
 * IMPORTANT: these helpers are built on Playwright's getByTestId(), but the backoffice's own
 * convention is `data-mark`, not the `data-testid` Playwright defaults to — without
 * `testIdAttribute: 'data-mark'` in playwright.config.ts, every one of them silently finds
 * nothing (verified empirically: a fresh dashboard load has 0 `data-testid` attributes and 18
 * `data-mark` ones, including `section-links` itself). That config is already set; don't remove
 * it or umbracoUi navigation breaks across the board.
 */
async function navigate(page: import('@playwright/test').Page, umbracoUi: UiHelpers) {
  // Example: open the first content node to show the editing workspace. There's no umbracoUi
  // helper for "whatever the first tree item happens to be" (its named helpers expect a known
  // content name), so this one case stays a raw locator.
  const firstNode = page.locator('umb-tree-item').first();
  if (await firstNode.count()) {
    await firstNode.getByRole('link').first().click().catch(() => {});
    await page.waitForTimeout(2_000);
  }
}
// ─── END CONFIG ──────────────────────────────────────────────────────────────

// page.setViewportSize() only changes the viewport — device scale factor is a browser-context
// creation option and can't be set per-page, so it must go through test.use() instead.
test.use({ viewport: VIEWPORT, deviceScaleFactor: DEVICE_SCALE_FACTOR });

test('capture docs screenshot', async ({ umbracoApi, umbracoUi, page }) => {
  await page.goto(`${BASE}/umbraco`, { waitUntil: 'networkidle' });
  await expect(page.locator('umb-app')).toBeVisible({ timeout: 30_000 });

  await page.goto(`${BASE}${ROUTE}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2_500);

  // TODO: seed deterministic content via umbracoApi here if the shot needs specific data.

  await navigate(page, umbracoUi);
  await page.waitForLoadState('networkidle');

  await page.screenshot({ path: OUTPUT, fullPage: false, ...(CLIP ? { clip: CLIP } : {}) });

  if (MATCH_MODE === 'exact') {
    const flag = EXACT_STRATEGY === 'crop' ? '-c' : '-z';
    // sips takes HEIGHT then WIDTH.
    execFileSync('sips', [flag, String(TARGET.height), String(TARGET.width), OUTPUT]);
  }
});
