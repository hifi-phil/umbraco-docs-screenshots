// Cross-platform runner behind `npm run test:v17|test:v18` (npm scripts run under cmd on Windows,
// where a POSIX `URL=... playwright test` prefix doesn't work). Sets URL for the chosen instance and
// passes any extra arguments through to Playwright.
// Usage: node scripts/test.mjs 17|18 [playwright args...]
//   e.g. npm run test:v18 -- tests/compare-content-v18.spec.ts --headed
import { spawnSync } from 'node:child_process';

const ports = { 17: '44322', 18: '44327' };
const [major, ...args] = process.argv.slice(2);
if (!ports[major]) {
  console.error('Usage: node scripts/test.mjs 17|18 [playwright args...]');
  process.exit(2);
}

const result = spawnSync(
  'npx',
  ['playwright', 'test', `--project=umbraco-${major}`, ...args],
  { stdio: 'inherit', shell: true, env: { ...process.env, URL: `https://localhost:${ports[major]}` } },
);
process.exit(result.status ?? 1);
