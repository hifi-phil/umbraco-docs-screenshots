import { test } from '@umbraco-cms/acceptance-test-helpers';
import { expect } from '@playwright/test';

/**
 * Headless capture of the Umbraco 18 backoffice, used to check whether the docs
 * "Comparing Content" screenshot still matches the current UI.
 *
 * Login is done via the Management API (umbracoApi fixture); the screenshots are
 * plain Playwright captures of the live backoffice.
 *
 * NOTE: navigation uses absolute URLs from process.env.URL on purpose — the
 * config `baseURL` (44343) points at a since-removed instance, so relative
 * page.goto() calls would hit the wrong site.
 */
const BASE = process.env.URL ?? 'https://localhost:44327';

test('capture v18 content UI for docs comparison', async ({ umbracoApi, page }) => {
  await page.goto(`${BASE}/umbraco`, { waitUntil: 'networkidle' });
  await expect(page.locator('umb-app')).toBeVisible({ timeout: 30_000 });

  // 1. Content section (tree + dashboard) as it first lands.
  await page.goto(`${BASE}/umbraco/section/content`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2_500);
  await page.screenshot({ path: 'screenshots/v18-content-section.png', fullPage: false });

  // 2. Expand the tree and open the first content node (Home in the Starter Kit)
  //    to show the content editing workspace — the surface the docs "Compare"
  //    dialog is layered on top of.
  const firstNode = page.locator('umb-tree-item').first();
  if (await firstNode.count()) {
    await firstNode.getByRole('link').first().click().catch(() => {});
    await page.waitForTimeout(3_000);
    await page.screenshot({ path: 'screenshots/v18-content-home.png', fullPage: false });
  }
});
