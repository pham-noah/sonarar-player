#!/usr/bin/env bash
# Prints the sha256 line to paste into the GitHub release body.
# The app checks a downloaded APK against it and deletes a mismatch, so a
# release published without this line updates without verification.
set -euo pipefail
apk="${1:-app_src/build/app/outputs/flutter-apk/app-release.apk}"
[ -f "$apk" ] || { echo "no APK at $apk — build it first" >&2; exit 1; }
printf 'sha256: %s\n' "$(sha256sum "$apk" | cut -d' ' -f1)"
