#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

FLUTTER="${FLUTTER:-/mnt/c/Windows/System32/cmd.exe}"
FLUTTER_CMD="${FLUTTER_CMD:-C:\\src\\flutter\\bin\\flutter.bat}"
fails=0

run() {  # run <label> <flutter args...>
  local label="$1"; shift
  printf '\n=== %s ===\n' "$label"
  "$FLUTTER" /c "$FLUTTER_CMD" "$@"
  local rc=$?
  [ $rc -ne 0 ] && { printf '!! %s FAILED (exit %s)\n' "$label" "$rc"; fails=$((fails+1)); }
  return 0
}

cd app_src || exit 2

run "analyze" analyze --fatal-infos

if [ "${1:-}" = "--full" ]; then
  run "test (all, live probe excluded)" test
else
  run "test (fast)" test --exclude-tags slow
fi

if [ "${1:-}" = "--apk" ]; then
  run "build release apk" build apk --release --target-platform android-arm64
fi

if [ "${1:-}" = "--live" ]; then
  run "live youtube probe (SLOW, fails by design)" test test/live
fi

printf '\n=== %s stage(s) failed ===\n' "$fails"
exit $fails
