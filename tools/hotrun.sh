#!/usr/bin/env bash

set -uo pipefail

ADB="/mnt/c/Users/Noah/AppData/Local/Android/Sdk/platform-tools/adb.exe"
CMD="/mnt/c/Windows/System32/cmd.exe"
FLUTTER='C:\\src\\flutter\\bin\\flutter.bat'
PROJECT="/mnt/c/Users/Noah/Documents/sonarar-player/app_src"

DEVICE="${DEVICE:-$("$ADB" devices 2>/dev/null | tr -d '\r' | awk 'NR>1 && $2=="device" {print $1; exit}')}"
if [[ -z "$DEVICE" ]]; then
  printf 'No device. Pair first:\n'
  printf '  %s pair <ip>:<pair_port>\n' "$ADB"
  printf '  %s connect <ip>:<port>      # the port on the Wireless debugging SCREEN, not the pairing one\n' "$ADB"
  exit 1
fi

printf 'hot run on %s\n' "$DEVICE"
printf 'press r = reload, R = restart, q = quit\n\n'

cd "$PROJECT" || exit 2

if [[ "${1:-}" == "--raw" ]]; then
  exec "$CMD" /c "$FLUTTER" run -d "$DEVICE"
fi

"$CMD" /c "$FLUTTER" run -d "$DEVICE" 2>&1 \
  | grep --line-buffered -vE 'cancelAndRedraw|FlutterActivityAndFragmentDelegate|^embedding\.android'
