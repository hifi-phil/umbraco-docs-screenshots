import { test } from '@umbraco-cms/acceptance-test-helpers';
import { expect } from '@playwright/test';
import { execFileSync } from 'node:child_process';

/**
 * Capture template for refreshing an outdated docs backoffice screenshot.
 *
 * Copy this file to tests/capture-<name>.spec.ts, edit the CONFIG block and the
 * navigate() function, then run it against the matching instance:
 *
 *   URL=https://localhost:44327 npx playwright test tests/capture-<name>.spec.ts --project=chromium
 *
 * Login is via the Management API (umbracoApi fixture); the screenshot is a plain
 * Playwright capture of the live backoffice.
 *
 * NOTE: navigation uses absolute URLs from process.env.URL on purpose — the config
 * baseURL (44343) points at a since-removed instance, so relative page.goto() calls
 * would hit the wrong site. Always pass URL=https://localhost:443xx on the CLI.
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
 * Edit these steps: expand tree, open a node, switch a workspace tab, open a menu/modal, etc.
 */
async function navigate(page: import('@playwright/test').Page) {
  // Example: open the first content node to show the editing workspace.
  const firstNode = page.locator('umb-tree-item').first();
  if (await firstNode.count()) {
    await firstNode.getByRole('link').first().click().catch(() => {});
    await page.waitForTimeout(2_000);
  }
}
// ─── END CONFIG ──────────────────────────────────────────────────────────────

test('capture docs screenshot', async ({ umbracoApi, page }) => {
  await page.setViewportSize(VIEWPORT);

  await page.goto(`${BASE}/umbraco`, { waitUntil: 'networkidle' });
  await expect(page.locator('umb-app')).toBeVisible({ timeout: 30_000 });

  await page.goto(`${BASE}${ROUTE}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2_500);

  // TODO: seed deterministic content via umbracoApi here if the shot needs specific data.

  await navigate(page);
  await page.waitForLoadState('networkidle');

  await page.screenshot({ path: OUTPUT, fullPage: false, ...(CLIP ? { clip: CLIP } : {}) });

  if (MATCH_MODE === 'exact') {
    const flag = EXACT_STRATEGY === 'crop' ? '-c' : '-z';
    // sips takes HEIGHT then WIDTH.
    execFileSync('sips', [flag, String(TARGET.height), String(TARGET.width), OUTPUT]);
  }
});
