#!/usr/bin/env bash
# Setup script for the Claude Code cloud environment the "Docs screenshot process" routine runs in.
# Paste it into the environment's setup script field (claude.ai → Code → environment settings).
# This copy is kept in the repo for version history only; the routine never runs it from here.
#
# What it fixes (each one was worked around by hand on every scheduled run):
#   1. No node_modules: every run spent time on `npm ci`.
#   2. Playwright 1.61.1 wants chromium_headless_shell-1228, but the image only has -1194, so every
#      run hand-patched `executablePath` into playwright.config.ts and reverted it afterwards.
#   3. Cold `dotnet run` builds made the first instance boot slow (one run hit a 300s timeout).
#   4. Vale wasn't installed, so renamed-image PRs were never linted.
#
# Every step is best-effort: a failure prints a warning and never fails the setup, because the
# skill still has its own fallbacks for each of these.

set -u

HARNESS="${HARNESS:-/home/user/umbraco-docs-screenshots}"
PLAYWRIGHT_VERSION="1.61.1"   # keep in sync with @playwright/test in package-lock.json
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"

warn() { echo "WARN (cloud-env-setup): $*" >&2; }

# 1. npm dependencies, if the harness has already been cloned when setup runs.
if [ -f "$HARNESS/package-lock.json" ]; then
  (cd "$HARNESS" && npm ci --no-audit --no-fund) || warn "npm ci failed; runs will install on demand"
else
  warn "$HARNESS not cloned yet; skipping npm ci (runs will install on demand)"
fi

# 2. The Chromium build that this Playwright version expects. Install with the pinned version
#    explicitly so it works whether or not node_modules exists yet. --with-deps needs apt; if that
#    fails, retry without the system packages (the image already has Chromium's libs for -1194).
npx -y "playwright@$PLAYWRIGHT_VERSION" install --with-deps chromium \
  || npx -y "playwright@$PLAYWRIGHT_VERSION" install chromium \
  || warn "Chromium install failed; runs fall back to the executablePath workaround (gotchas.md)"

# 3. Pre-build both demo instances so first boot only has to start, not compile.
if command -v dotnet >/dev/null 2>&1 && [ -d "$HARNESS/demo" ]; then
  for v in v17 v18; do
    dotnet build "$HARNESS/demo/$v" --nologo -v q || warn "dotnet build $v failed"
  done
fi

# 4. Vale, for linting markdown that a renamed image touched (publish-pr.md). Optional.
if ! command -v vale >/dev/null 2>&1; then
  VALE_URL=$(curl -fsSL https://api.github.com/repos/errata-ai/vale/releases/latest \
    | grep -o 'https://[^"]*Linux_64-bit\.tar\.gz' | head -1)
  if [ -n "$VALE_URL" ] && curl -fsSL "$VALE_URL" | tar -xz -C /usr/local/bin vale; then
    vale --version
  else
    warn "Vale install failed; runs will skip linting"
  fi
fi

exit 0
