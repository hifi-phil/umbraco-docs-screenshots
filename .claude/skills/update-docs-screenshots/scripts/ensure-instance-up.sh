#!/usr/bin/env bash
# Confirm the matching demo instance is up, starting it if needed (Step 4).
#
# Usage: ensure-instance-up.sh <17|18> <harness-root> [timeout-seconds]
#
# If the instance's port is already listening, returns immediately. Otherwise starts
# `dotnet run --project vNN` in the background (log at /tmp/umbraco-demo-vNN.log — never inside
# the repo) and polls the log for `Now listening on:`, which is the only reliable readiness
# signal: transient `SQLite Error 14: unable to open database file` lines on first boot are
# expected and ignored.
#
# Exit codes:
#   0 — instance is up
#   1 — bad arguments, or timed out waiting for it to start

set -u

VERSION="${1:-}"
HARNESS="${2:-}"
TIMEOUT="${3:-90}"

case "$VERSION" in
  17) PORT=44322 ;;
  18) PORT=44327 ;;
  *)
    echo "Usage: ensure-instance-up.sh <17|18> <harness-root> [timeout-seconds]" >&2
    exit 1
    ;;
esac

if [ -z "$HARNESS" ] || [ ! -d "$HARNESS/demo/v$VERSION" ]; then
  echo "harness-root '$HARNESS' has no demo/v$VERSION project." >&2
  exit 1
fi

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "v$VERSION instance already listening on $PORT."
  exit 0
fi

LOG="/tmp/umbraco-demo-v$VERSION.log"
echo "Starting v$VERSION (logging to $LOG)..."
(cd "$HARNESS/demo" && nohup dotnet run --project "v$VERSION" > "$LOG" 2>&1 &)

SECONDS=0
while ! grep -q "Now listening on:" "$LOG" 2>/dev/null; do
  if [ "$SECONDS" -gt "$TIMEOUT" ]; then
    echo "Timed out after ${TIMEOUT}s waiting for v$VERSION to start. Check $LOG." >&2
    exit 1
  fi
  sleep 2
done

echo "v$VERSION instance is up on $PORT."
