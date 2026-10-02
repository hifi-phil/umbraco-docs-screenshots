// Cross-platform runner for tests/setup/mcp-api-user.spec.ts (npm scripts run under cmd on
// Windows, where a POSIX `URL=... cmd` prefix doesn't work). Usage: node scripts/mcp-setup.mjs 17|18
import { spawnSync } from 'node:child_process';

const ports = { 17: '44322', 18: '44327' };
const major = process.argv[2];
if (!ports[major]) {
  console.error('Usage: node scripts/mcp-setup.mjs 17|18');
  process.exit(2);
}

const result = spawnSync(
  'npx',
  ['playwright', 'test', 'tests/setup/mcp-api-user.spec.ts', `--project=umbraco-${major}`, '--reporter=line'],
  { stdio: 'inherit', shell: true, env: { ...process.env, URL: `https://localhost:${ports[major]}`, MCP_SETUP: '1' } },
);
process.exit(result.status ?? 1);
