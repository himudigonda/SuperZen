#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

[ $# -eq 2 ] || { echo "usage: $0 <SuperZen.app> <output dir>" >&2; exit 1; }
APP="$1"
OUTPUT="$2"
BINARY="$APP/Contents/MacOS/SuperZen"
ALIVE_SECONDS="${SMOKE_ALIVE_SECONDS:-25}"

[ -x "$BINARY" ] || { echo "error: no executable at $BINARY" >&2; exit 1; }
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"

echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
vtool -show-build "$BINARY" | grep -E "minos|sdk" | sort -u
scripts/check_symbols.sh "$BINARY"

HOME_DIR="$(mktemp -d)"
mkdir -p "$HOME_DIR/Library/Application Support" "$HOME_DIR/Library/Preferences"
CFFIXED_USER_HOME="$HOME_DIR" "$BINARY" >"$OUTPUT/app.log" 2>&1 &
PID=$!

sleep "$ALIVE_SECONDS"
if ! kill -0 "$PID" 2>/dev/null; then
  STATUS=0
  wait "$PID" || STATUS=$?
  echo "error: app exited with status $STATUS within $ALIVE_SECONDS seconds" >&2
  tail -40 "$OUTPUT/app.log" >&2
  find "$HOME/Library/Logs/DiagnosticReports" -name 'SuperZen*' -exec cp {} "$OUTPUT/" \; 2>/dev/null || true
  exit 1
fi

screencapture -x "$OUTPUT/launch.png" || echo "warning: screen capture is not available here"
ps -o %cpu=,rss= -p "$PID" | awk '{printf "cpu %s%%, memory %d MB\n", $1, $2 / 1024}'
kill "$PID"
wait "$PID" 2>/dev/null || true
[ -f "$HOME_DIR/Library/Application Support/SuperZen/telemetry.store" ] || {
  echo "error: the telemetry store was not created in the app's folder" >&2
  exit 1
}
echo "launch smoke passed"
