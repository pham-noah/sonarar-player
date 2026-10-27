#!/usr/bin/env bash

set -uo pipefail

PROJECT="/mnt/c/Users/Noah/Documents/sonarar-player/app_src"
RELEASE="$PROJECT/build/app/outputs/flutter-apk/app-release.apk"

RELEASE_WIN="$(printf '%s' "$RELEASE" | sed -E 's#^/mnt/([a-z])/#\U\1:/#')"

ADB="/mnt/c/Users/Noah/AppData/Local/Android/Sdk/platform-tools/adb.exe"
CMD="/mnt/c/Windows/System32/cmd.exe"
FLUTTER='C:\src\flutter\bin\flutter.bat'

say() { printf '%s\n' "$*"; }
die() { printf '\nSTOPPED: %s\n' "$*" >&2; exit 1; }

[[ -x "$ADB" ]] || die "adb not found at $ADB — check the SDK path."
[[ -x "$CMD" ]] || die "cmd.exe not found — cannot reach the Windows Flutter SDK."

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  say "== building the release APK =="
  cd "$PROJECT" || die "project folder missing: $PROJECT"
  "$CMD" /c "$FLUTTER build apk --release --target-platform android-arm64" 2>&1 | tail -4
  [[ -f "$RELEASE" ]] || die "build finished but $RELEASE is not there."
else
  say "== skipping build (SKIP_BUILD=1) =="
fi

[[ -f "$RELEASE" ]] || die "no APK at $RELEASE — build first."

say ""
say "== looking for a device =="
DEVICES="$("$ADB" devices | tr -d '\r' | awk 'NR>1 && $2=="device" {print $1}')"

if [[ -z "$DEVICES" ]]; then
  say ""
  say "No device attached."
  say ""
  say "To pair the phone (once per phone, and again after any reboot):"
  say "  1. On the phone: Settings > Developer options > Wireless debugging > ON"
  say "  2. Tap 'Pair device with pairing code'. It shows an IP:PORT and a code."
  say "  3. From here, run (substituting what the phone shows):"
  say "       $ADB pair <ip>:<pair_port>"
  say "  4. Then connect on the port from the Wireless debugging SCREEN:"
  say "       $ADB connect <ip>:<port>"
  say "  5. Re-run this script."
  say ""
  say "The pairing port and the connect port are DIFFERENT. Using the pairing"
  say "port to connect is the mistake that makes it look broken."
  exit 1
fi

say "found: $DEVICES"
COUNT="$(printf '%s\n' "$DEVICES" | wc -l)"
if [[ "$COUNT" -gt 1 ]]; then
  die "$COUNT devices attached. Disconnect all but the target — installing to the wrong phone is silent."
fi

say ""
say "== installing =="
if ! "$ADB" install -r "$RELEASE_WIN" 2>&1 | tail -3; then
  die "the install FAILED — nothing was put on the phone. Build output above; the APK is at $RELEASE."
fi
INSTALLED=$("$ADB" shell dumpsys package com.noah.personar 2>/dev/null | grep -m1 lastUpdateTime)
if [[ -z "$INSTALLED" ]]; then
  die "the package is not on the device after install — the install did not take."
fi

say ""
say "== installed version on device =="
"$ADB" shell dumpsys package com.noah.personar 2>/dev/null \
  | grep -m1 versionName || say "  (could not read versionName)"

say ""
say "== crash check: launching and reading the log =="
"$ADB" logcat -c 2>/dev/null
"$ADB" shell am force-stop com.noah.personar 2>/dev/null
"$ADB" shell monkey -p com.noah.personar -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 15

CRASHES="$("$ADB" logcat -d 2>/dev/null \
  | grep -av ' adbd ' \
  | grep -acE 'FATAL EXCEPTION|Could not load library|Another exception was thrown|UnsatisfiedLinkError|ExceptionInInitializerError|NoClassDefFoundError')"

if [[ "$CRASHES" -gt 0 ]]; then
  say ""
  say "!! $CRASHES crash signature(s) after launch — this build is NOT usable:"
  "$ADB" logcat -d 2>/dev/null \
    | grep -av ' adbd ' \
    | grep -aE 'FATAL EXCEPTION|Could not load library|Another exception was thrown|UnsatisfiedLinkError|ExceptionInInitializerError|NoClassDefFoundError' \
    | head -8
  exit 1
fi
say "  0 crash signatures — the release build launched clean"

say ""
say "Next: push the library with tools/sync_library.py, then open the app once."
say "Screen-off audio needs a real swipe-from-Recents test — see the README."
