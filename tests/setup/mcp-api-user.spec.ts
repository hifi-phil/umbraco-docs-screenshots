import { test } from '@umbraco-cms/acceptance-test-helpers-v18';
import { expect } from '@playwright/test';
import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * One-off setup for the shared MCP servers in .mcp.json — not a screenshot test.
 *
 * Creates (or resets) the dedicated MCP API user on one demo instance, gives it a fresh client
 * secret, proves the secret works, and stores it as UMBRACO_MCP_V<major>_CLIENT_SECRET in the
 * gitignored .claude/settings.local.json, which is where .mcp.json reads it from. Run it once per
 * instance, per machine (the user lives in the gitignored SQLite DB), then restart Claude Code:
 *
 *   npm run mcp:setup:v17
 *   npm run mcp:setup:v18
 *
 * Skipped unless MCP_SETUP=1, so a plain `npx playwright test` never resets credentials.
 * Only Management API calls are made, so the v18 helper import works against v17 too.
 */
const BASE = process.env.URL!;
const API = `${BASE}/umbraco/management/api/v1`;
const MAJOR = { '44322': '17', '44327': '18' }[new URL(BASE).port];
const EMAIL = 'mcp@admin.com';
const CLIENT_ID = 'umbraco-back-office-mcp';
const ENV_VAR = `UMBRACO_MCP_V${MAJOR}_CLIENT_SECRET`;
const SETTINGS = join(process.cwd(), '.claude', 'settings.local.json');

test.skip(process.env.MCP_SETUP !== '1', 'MCP setup only runs via npm run mcp:setup:v17|v18');

test('set up MCP API user', async ({ umbracoApi, page }) => {
  expect(MAJOR, `URL ${BASE} is not a demo instance (44322 or 44327)`).toBeTruthy();
  const secret = process.env.MCP_CLIENT_SECRET || randomBytes(24).toString('base64url');
  const headers = await umbracoApi.getHeaders();
  const req = page.request;

  const groups = await (await req.get(`${API}/user-group?skip=0&take=100`, { headers })).json();
  const admin = groups.items.find((g: any) => g.alias === 'admin');
  expect(admin, 'Administrators group').toBeTruthy();

  const found = await (await req.get(`${API}/filter/user?skip=0&take=10&filter=${encodeURIComponent(EMAIL)}`, { headers })).json();
  let id: string | undefined = found.items?.find((u: any) => u.email === EMAIL)?.id;
  if (!id) {
    const res = await req.post(`${API}/user`, {
      headers,
      data: { email: EMAIL, userName: EMAIL, name: 'MCP API User', kind: 'Api', userGroupIds: [{ id: admin.id }] },
    });
    expect(res.status(), await res.text()).toBe(201);
    id = res.headers()['umb-generated-resource'] ?? res.headers()['location']?.split('/').pop();
  }

  const existing = await (await req.get(`${API}/user/${id}/client-credentials`, { headers })).json();
  if (Array.isArray(existing) && existing.includes(CLIENT_ID)) {
    await req.delete(`${API}/user/${id}/client-credentials/${CLIENT_ID}`, { headers });
  }
  const cred = await req.post(`${API}/user/${id}/client-credentials`, { headers, data: { clientId: CLIENT_ID, clientSecret: secret } });
  expect(cred.ok(), await cred.text()).toBeTruthy();

  const token = await req.post(`${API}/security/back-office/token`, {
    form: { grant_type: 'client_credentials', client_id: CLIENT_ID, client_secret: secret },
  });
  expect(token.ok(), await token.text()).toBeTruthy();

  const settings = existsSync(SETTINGS) ? JSON.parse(readFileSync(SETTINGS, 'utf8')) : {};
  settings.env = { ...settings.env, [ENV_VAR]: secret };
  mkdirSync(join(process.cwd(), '.claude'), { recursive: true });
  writeFileSync(SETTINGS, JSON.stringify(settings, null, 2) + '\n');
  console.log(`MCP API user ready on ${BASE}; ${ENV_VAR} saved to .claude/settings.local.json. Restart Claude Code.`);
});
