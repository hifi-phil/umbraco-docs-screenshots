import { test } from '@umbraco-cms/acceptance-test-helpers';
import { expect } from '@playwright/test';

/**
 * Connects to the local Umbraco demo instance using the official Umbraco
 * acceptance-test-helpers.
 *
 * The `umbracoApi` fixture authenticates before the test body runs: it tries to
 * refresh an existing token, and when that fails it performs a full re-login via
 * the Management API using UMBRACO_USER_LOGIN / UMBRACO_USER_PASSWORD (defaulted
 * to the demo admin in playwright.config.ts). No credentials are typed into the UI.
 */
test('logs into the backoffice via the helpers and screenshots the dashboard', async ({ umbracoApi, umbracoUi, page }) => {
  // umbracoApi is injected first, so we're already authenticated at this point.
  await umbracoUi.goToBackOffice();

  // Wait for the Bellissima backoffice shell + the section sidebar to render.
  await expect(page).toHaveURL(/\/umbraco/);
  await expect(page.locator('umb-app')).toBeVisible({ timeout: 30_000 });
  await expect(page.locator('umb-backoffice-header').first()).toBeVisible({ timeout: 30_000 });
  await page.waitForLoadState('networkidle');

  await page.screenshot({ path: 'screenshots/backoffice-dashboard.png', fullPage: false });

  // Keep the window on screen briefly when watching in headed mode (SHOW=1).
  if (process.env.SHOW) {
    await page.waitForTimeout(8_000);
  }
});
