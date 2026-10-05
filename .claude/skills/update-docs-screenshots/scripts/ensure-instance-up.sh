#!/usr/bin/env bash
# Confirm the matching demo instance is up, starting it if needed (Step 4).
#
# Usage: ensure-instance-up.sh <17|18> <harness-root> [timeout-seconds]
#
# "Up" means the backoffice answers HTTP on its port (checked with curl, which exists on Windows
# Git Bash, Linux and macOS). This used to be `lsof -iTCP:<port> -sTCP:LISTEN`, but Git Bash on
# Windows has no lsof: the check always failed, so every run started a second `dotnet run` next to
# the healthy instance, whose build then failed on the locked vNN.exe (MSB3027), overwrote the log
# and timed out waiting for `Now listening on:`.
#
# If the instance doesn't answer, any process still running this project's own executable is
# stopped first (alive-but-not-listening, or holding the exe), then `dotnet run --project vNN`
# starts in the background (log at /tmp/umbraco-demo-vNN.log — never inside the repo). Readiness is
# the same HTTP check; transient `SQLite Error 14: unable to open database file` lines on first
# boot are expected and ignored. A failed build in the log fails fast instead of waiting out the
# timeout.
#
# Exit codes:
#   0 — instance is up
#   1 — bad arguments, build failed, or timed out waiting for it to start

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

# Any HTTP status (200, 302, …) means Kestrel is serving; 000 means nothing answered.
is_up() {
  local code
  code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://localhost:$PORT/umbraco" 2>/dev/null)
  [ -n "$code" ] && [ "$code" != "000" ]
}

# Stop only processes running THIS project's build output — never anything else.
stop_stale() {
  if command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    local exe
    exe="$(cygpath -w "$HARNESS/demo/v$VERSION/bin/Debug/net10.0/v$VERSION.exe")"
    powershell.exe -NoProfile -Command "Get-Process v$VERSION -ErrorAction SilentlyContinue | Where-Object { \$_.Path -eq '$exe' } | ForEach-Object { Write-Output \"Stopping stale v$VERSION process \$(\$_.Id) (running but not answering on $PORT).\"; Stop-Process -Id \$_.Id -Force }"
  else
    pkill -f "$HARNESS/demo/v$VERSION/bin/" && echo "Stopped stale v$VERSION process (running but not answering on $PORT)."
  fi
  return 0
}

if is_up; then
  echo "v$VERSION instance already up on $PORT."
  exit 0
fi

stop_stale
sleep 2

LOG="/tmp/umbraco-demo-v$VERSION.log"
echo "Starting v$VERSION (logging to $LOG)..."
(cd "$HARNESS/demo" && nohup dotnet run --project "v$VERSION" > "$LOG" 2>&1 &)

SECONDS=0
until is_up; do
  if grep -q "The build failed" "$LOG" 2>/dev/null; then
    echo "v$VERSION build failed — see $LOG." >&2
    grep -E "error [A-Z]+[0-9]+" "$LOG" | head -3 >&2
    exit 1
  fi
  if [ "$SECONDS" -gt "$TIMEOUT" ]; then
    echo "Timed out after ${TIMEOUT}s waiting for v$VERSION to start. Check $LOG." >&2
    exit 1
  fi
  sleep 2
done

echo "v$VERSION instance is up on $PORT."
