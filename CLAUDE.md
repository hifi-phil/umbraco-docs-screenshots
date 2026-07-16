# CLAUDE.md

Guidance for working in this repository.

## What this project is

A workspace for capturing screenshots of the Umbraco backoffice (for documentation),
built from two parts:

1. **`demo/`** — local Umbraco CMS instances to screenshot against. There is one
   instance **per documented Umbraco version** (currently **17** and **18**) so the
   same screenshot can be captured against each major.
2. **Playwright** (repo root) — the browser automation / test harness that drives the
   backoffice and captures the screenshots.

## Layout

```
.
├── CLAUDE.md                 # this file
├── package.json              # Playwright test project (repo root)
├── playwright.config.ts      # Playwright config (TypeScript, Chromium only)
├── tests/
│   └── backoffice-login.spec.ts   # helper-based login + screenshot
└── demo/
    ├── v17/                  # Umbraco 17 web project  (screenshot target)
    └── v18/                  # Umbraco 18 web project  (screenshot target)
```

Each version project (`v17/`, `v18/`) contains its own `<name>.csproj`,
`Directory.Packages.props` (pinned versions), `appsettings*.json`, `Program.cs`,
`Properties/launchSettings.json`, and `umbraco/` app folder with a SQLite DB under
`umbraco/Data/`.

## The Umbraco demo instances

The screenshot targets are `demo/v17` and `demo/v18`. Both target framework
`net10.0`, use SQLite, install unattended on first boot, and share the same admin
login.

| | `demo/v17` | `demo/v18` |
|---|---|---|
| Umbraco (`Umbraco.Cms`) | **17.5.3** | **18.0.2** |
| Starter kit | `Umbraco.TheStarterKit` 17.0.0 | `Umbraco.TheStarterKit` 18.0.0 |
| Backoffice | https://localhost:44322/umbraco | https://localhost:44327/umbraco |
| Frontend (https) | https://localhost:44322 | https://localhost:44327 |
| Frontend (http) | http://localhost:60011 | http://localhost:38671 |
| Database | SQLite — `demo/v17/umbraco/Data/Umbraco.sqlite.db` | SQLite — `demo/v18/umbraco/Data/Umbraco.sqlite.db` |

**Admin login (both):** `admin@admin.com` / `1234567890` — provisioned via
`InstallUnattended` in `appsettings.Development.json`.

Package versions are pinned centrally in each project's `Directory.Packages.props`
(central package management is on). Keep each project's `Umbraco.Cms` and
`Umbraco.TheStarterKit` majors aligned (17 kit with 17 CMS, 18 kit with 18 CMS) to
avoid `NU1107` version-conflict errors.

### Run the CMS

```bash
cd demo
dotnet run --project v17     # serves https://localhost:44322
dotnet run --project v18     # serves https://localhost:44327
```

Run each in its own terminal (or background) so both are up at once. On first boot
you may see transient `SQLite Error 14: unable to open database file` lines before the
DB is created — these are expected; wait for `Now listening on:`.

## Playwright (repo root)

| | |
|---|---|
| Runner | `@playwright/test` 1.61.x, TypeScript |
| Browsers | Chromium only installed (Firefox/WebKit commented out in config) |
| Umbraco helpers | `@umbraco-cms/acceptance-test-helpers` — **one version per CMS major** |

### Umbraco test helpers

Use `@umbraco-cms/acceptance-test-helpers` — the **successor** to the now-deprecated
`@umbraco/playwright-testhelpers`. Its version tracks the CMS major/minor exactly.
Because we drive **both 17 and 18**, both helper versions are needed:

- **17.5.3** for `demo/v17`
- **18.0.2** for `demo/v18`

The helpers read their target URL and credentials from **global `process.env`** at
import time:

| Env var | Meaning | Default in this repo |
|---|---|---|
| `URL` | backoffice base URL | set per run/project |
| `UMBRACO_USER_LOGIN` | admin email | `admin@admin.com` |
| `UMBRACO_USER_PASSWORD` | admin password | `1234567890` |

Because that config is read once at import, the target URL is fixed per **process**.
Version selection is therefore done with **Playwright projects** (`umbraco-17` /
`umbraco-18`), each pointing at its own base URL and using the matching helper version.

```typescript
import { test, ApiHelpers, UiHelpers, ConstantHelper } from '@umbraco-cms/acceptance-test-helpers';

test('example', async ({ umbracoApi, umbracoUi }) => {
  // umbracoApi — fast API setup/teardown + login (handles token/CSRF)
  // umbracoUi  — backoffice navigation helpers
});
```

The `test` fixture authenticates before the test body runs: it tries a token refresh,
and when that fails (cold start) performs a full re-login via the Management API using
`UMBRACO_USER_LOGIN` / `UMBRACO_USER_PASSWORD`. No credentials are typed into the UI.

Recommended split for this project: use `umbracoApi` for **login + seeding
deterministic content/data**, and raw Playwright (`page.screenshot()` etc.) for the
actual screenshot capture, so you keep precise control over what's on screen.

```bash
npx playwright test            # headless
npx playwright test --ui       # interactive UI mode
npx playwright test --headed   # watch a real browser window
npx playwright codegen         # record actions into a test
npx playwright install firefox webkit   # add more browsers if needed
```

### Gotchas when testing against the local Umbraco

- The dev sites use **self-signed HTTPS certs**. `ignoreHTTPSErrors: true` is set in
  `playwright.config.ts` (`use` block) — required or requests to
  `https://localhost:443xx` fail.
- Target URLs: **v17 → `https://localhost:44322`**, **v18 → `https://localhost:44327`**.
  Select the version via the Playwright project rather than a single global `baseURL`.
- The relevant Umbraco instance(s) must be running before Playwright tests execute.
  A `webServer` block in `playwright.config.ts` can launch `dotnet run` automatically.
- ⚠️ **`playwright.config.ts` `baseURL` / `process.env.URL` default is stale (`44343`)** —
  that port belongs to no current instance (v17 = 44322, v18 = 44327). The helper reads
  `process.env.URL` for **API login**, but the browser resolves relative `page.goto()`
  paths against **`baseURL`** — so a wrong `baseURL` silently sends the browser to a
  different (or dead) site while login still "succeeds". Until the config is fixed, pass
  `URL=https://localhost:443xx` **and** navigate with **absolute URLs** in the spec (see
  `tests/compare-content-v18.spec.ts`), or set `baseURL: process.env.URL`.
- **Check for stray/stale processes before trusting a port.** A removed legacy instance
  (`demo/Demo`, deleted in git) can leave a `dotnet run` process still bound to a port
  (it was found on `44343`). Its source `wwwroot` is gone, so its login page throws
  `ArgumentException: The directory name '.../demo/Demo/wwwroot/' does not exist`. If you
  see that error, a ghost instance is answering — find it with
  `lsof -nP -iTCP:<port> -sTCP:LISTEN` / `ps aux | grep Demo` and stop it.
- **Don't nest one version project inside another.** A stray `demo/v18/demo/v17/` copy
  makes the v18 build pull in a second `Program.cs` → `CS8802: Only one compilation unit
  can have top-level statements`. Each version project must be a single flat folder.

### What is (and isn't) screenshottable on a local instance

- The backoffice was **fully redesigned in v14+ ("Bellissima", Lit/web-components)**. Any
  docs screenshot showing the **old AngularJS UI** (circular logo + horizontal section
  tabs, a `Forms` tab, etc.) is **outdated for v17/v18** — the entire chrome, tree,
  workspace, and buttons differ.
- **Compare / Queue for transfer / Transfer now / Partial restore are Umbraco Deploy
  (Cloud) features** — they compare a *Current* vs *Live* environment. A vanilla local
  single-environment CMS has none of this, so those dialogs **cannot be reproduced
  locally** regardless of version.

## Conventions

- Temporary/scratch files do not belong in the repo.
- The root `.gitignore` ignores `node_modules/`, `test-results/`, `playwright-report/`,
  and Playwright caches. Each Umbraco project has its own `.gitignore`.
