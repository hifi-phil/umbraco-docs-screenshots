#!/usr/bin/env bash
# Setup script for the Claude Code cloud environment the "Docs screenshot process" routine runs in.
# Paste it into the environment's setup script field (claude.ai → Code → environment settings).
# This copy is kept in the repo for version history only; the routine never runs it from here.
#
# Only installs things OUTSIDE the repo checkouts. Don't rely on the routine's repos existing when
# this runs (or on anything written into them surviving): it can run before they're cloned, and its
# result is cached and reused across runs. Repo-local setup (`npm ci`) is done by the skill itself
# in Step 4 instead.
#
# What it fixes (each one was worked around by hand on every scheduled run):
#   1. Playwright 1.61.1 wants chromium_headless_shell-1228, but the image only has -1194, so every
#      run hand-patched `executablePath` into playwright.config.ts and reverted it afterwards.
#   2. Vale wasn't installed, so renamed-image PRs were never linted.
#
# Every step is best-effort: a failure prints a warning and never fails the setup, because the
# skill still has its own fallbacks for each of these.

set -u

PLAYWRIGHT_VERSION="1.61.1"   # keep in sync with @playwright/test in package-lock.json
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"

warn() { echo "WARN (cloud-env-setup): $*" >&2; }

# 1. The Chromium build that this Playwright version expects. Install with the pinned version
#    explicitly, so no repo or node_modules is needed; it lands in $PLAYWRIGHT_BROWSERS_PATH.
#    --with-deps needs apt; if that fails, retry without the system packages (the image already
#    has Chromium's libs for -1194).
npx -y "playwright@$PLAYWRIGHT_VERSION" install --with-deps chromium \
  || npx -y "playwright@$PLAYWRIGHT_VERSION" install chromium \
  || warn "Chromium install failed; runs fall back to the executablePath workaround (gotchas.md)"

# 2. Vale, for linting markdown that a renamed image touched (publish-pr.md). Optional.
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
