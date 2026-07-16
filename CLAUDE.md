# CLAUDE.md

Guidance for working in this repository.

## What this project is

A workspace for capturing screenshots of the Umbraco backoffice (for documentation),
built from two parts:

1. **`demo/`** — a local Umbraco 17 CMS instance to screenshot against.
2. **Playwright** (repo root) — the browser automation / test harness that drives the
   backoffice and captures the screenshots.

## Layout

```
.
├── CLAUDE.md                 # this file
├── package.json              # Playwright test project (repo root)
├── playwright.config.ts      # Playwright config (TypeScript, Chromium only)
├── tests/
│   └── example.spec.ts       # default scaffold test (not yet customised)
└── demo/
    ├── Demo.slnx             # solution file (.NET 10 slnx format)
    └── Demo/                 # Umbraco 17 web project
        ├── Demo.csproj
        ├── Directory.Packages.props   # central package versions (pinned)
        ├── appsettings.json
        ├── Program.cs
        ├── Views/ wwwroot/ umbraco/   # Umbraco app + SQLite DB under umbraco/Data/
```

## The Umbraco demo instance (`demo/Demo`)

| | |
|---|---|
| Umbraco | 17.5.3 (`Umbraco.Cms`), target framework `net10.0` |
| Starter kit | `Clean` 7.0.8 (targets Umbraco 17) |
| Database | SQLite — `demo/Demo/umbraco/Data/Umbraco.sqlite.db` |
| Backoffice | https://localhost:44343/umbraco |
| Frontend | https://localhost:44343 (also http://localhost:53960) |
| Admin login | `admin@admin.com` / `1234567890` |

Package versions are pinned centrally in `demo/Demo/Directory.Packages.props`
(central package management is on). Keep `Clean` on a **7.x** version — Clean 8.x
targets Umbraco 18 and causes an `NU1107` `Umbraco.Cms.Web.Common` version conflict
against the Umbraco 17 packages.

### Run the CMS

```bash
cd demo
dotnet run --project Demo          # serves https://localhost:44343
```

On first boot you may see transient `SQLite Error 14: unable to open database file`
lines before the DB is created — these are expected; wait for `Now listening on:`.

## Playwright (repo root)

| | |
|---|---|
| Runner | `@playwright/test` 1.61.x, TypeScript |
| Browsers | Chromium only installed (Firefox/WebKit commented out in config) |
| Umbraco helpers | `@umbraco-cms/acceptance-test-helpers` **17.5.3** (matches the CMS) |

### Umbraco test helpers

Use `@umbraco-cms/acceptance-test-helpers` — the **successor** to the now-deprecated
`@umbraco/playwright-testhelpers`. Its version tracks the CMS major/minor exactly, so
keep it pinned to the Umbraco version in `demo/` (currently **17.5.3**). Peer dep:
`@playwright/test >= 1.56`.

```typescript
import { test, ApiHelpers, UiHelpers, ConstantHelper } from '@umbraco-cms/acceptance-test-helpers';

test('example', async ({ umbracoApi, umbracoUi }) => {
  // umbracoApi — fast API setup/teardown + login (handles token/CSRF)
  // umbracoUi  — backoffice navigation helpers
});
```

Recommended split for this project: use `umbracoApi` for **login + seeding
deterministic content/data**, and raw Playwright (`page.screenshot()` etc.) for the
actual screenshot capture, so you keep precise control over what's on screen.

```bash
npx playwright test            # headless
npx playwright test --ui       # interactive UI mode
npx playwright codegen         # record actions into a test
npx playwright install firefox webkit   # add more browsers if needed
```

### Gotchas when testing against the local Umbraco

- The dev site uses a **self-signed HTTPS cert**. Set `ignoreHTTPSErrors: true` in
  `playwright.config.ts` `use` block (not set by default) or requests to
  `https://localhost:44343` will fail.
- No `baseURL` is configured yet — either add
  `baseURL: 'https://localhost:44343'` to the config or use absolute URLs.
- The Umbraco CMS must be running (see above) before Playwright tests execute.
  Consider wiring `webServer` in `playwright.config.ts` to launch `dotnet run`
  automatically.

## Conventions

- Temporary/scratch files do not belong in the repo.
- The root `.gitignore` ignores `node_modules/`, `test-results/`, `playwright-report/`,
  and Playwright caches. The Umbraco project has its own `.gitignore` in `demo/Demo/`.
