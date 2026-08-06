import { defineConfig, devices } from '@playwright/test';

/**
 * The @umbraco-cms/acceptance-test-helpers read these straight off process.env at import time,
 * so the target is fixed per process. There is no single correct default across v17/v18 — pass
 * URL=https://localhost:44322|44327 explicitly (see CLAUDE.md), or select the `umbraco-17`/
 * `umbraco-18` project below, which set the matching baseURL for relative page.goto() calls.
 * (44327/v18 is used here only so an unparameterized run has *some* working default.)
 */
process.env.URL ??= 'https://localhost:44327';
process.env.UMBRACO_USER_LOGIN ??= 'admin@admin.com';
process.env.UMBRACO_USER_PASSWORD ??= '1234567890';

/**
 * Read environment variables from file.
 * https://github.com/motdotla/dotenv
 */
// import dotenv from 'dotenv';
// import path from 'path';
// dotenv.config({ path: path.resolve(__dirname, '.env') });

/**
 * See https://playwright.dev/docs/test-configuration.
 */
export default defineConfig({
  testDir: './tests',
  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  /* Opt out of parallel tests on CI. */
  workers: process.env.CI ? 1 : undefined,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: 'html',
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('')`. Tied to the same env var the
       acceptance-test-helpers read, so the two can't drift apart like the old hardcoded 44343
       default did (that port belongs to no current instance). */
    baseURL: process.env.URL,

    /* The local Umbraco dev site uses a self-signed HTTPS cert. */
    ignoreHTTPSErrors: true,

    /* The backoffice's own convention is `data-mark`, not Playwright's `data-testid` default —
       the acceptance-test-helpers' locators are built on getByTestId(), so without this every
       one of them silently finds nothing (confirmed empirically: 0 data-testid attributes vs.
       18 data-mark ones on a plain dashboard load, including "section-links" itself). */
    testIdAttribute: 'data-mark',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },

    /* Version-scoped projects: pass URL=https://localhost:44322|44327 on the CLI to match
       (process.env.URL is read by the helpers at import time, before project `use` applies —
       the project only fixes baseURL for relative page.goto() calls within the test). */
    {
      name: 'umbraco-17',
      use: { ...devices['Desktop Chrome'], baseURL: 'https://localhost:44322' },
    },
    {
      name: 'umbraco-18',
      use: { ...devices['Desktop Chrome'], baseURL: 'https://localhost:44327' },
    },

    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },

    // {
    //   name: 'webkit',
    //   use: { ...devices['Desktop Safari'] },
    // },

    /* Test against mobile viewports. */
    // {
    //   name: 'Mobile Chrome',
    //   use: { ...devices['Pixel 5'] },
    // },
    // {
    //   name: 'Mobile Safari',
    //   use: { ...devices['iPhone 12'] },
    // },

    /* Test against branded browsers. */
    // {
    //   name: 'Microsoft Edge',
    //   use: { ...devices['Desktop Edge'], channel: 'msedge' },
    // },
    // {
    //   name: 'Google Chrome',
    //   use: { ...devices['Desktop Chrome'], channel: 'chrome' },
    // },
  ],

  /* Run your local dev server before starting the tests */
  // webServer: {
  //   command: 'npm run start',
  //   url: 'http://localhost:3000',
  //   reuseExistingServer: !process.env.CI,
  // },
});
