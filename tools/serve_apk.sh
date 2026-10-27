#!/usr/bin/env bash

set -uo pipefail

APK_DIR="/mnt/c/Users/Noah/Documents/PersonaR/app_src/build/app/outputs/flutter-apk"
APK="$APK_DIR/app-release.apk"
SHARE="$APK_DIR/share"
PORT="${PORT:-8777}"
CMD="/mnt/c/Windows/System32/cmd.exe"

say() { printf '%s\n' "$*"; }
die() { printf '\nSTOPPED: %s\n' "$*" >&2; exit 1; }

[[ -f "$APK" ]] || die "No APK at $APK — build it first:
  cd $APK_DIR/.. && /mnt/c/Windows/System32/cmd.exe /c \"C:\\src\\flutter\\bin\\flutter.bat build apk --release\""

mkdir -p "$SHARE"
cp -f "$APK" "$SHARE/personar.apk"
[[ -s "$SHARE/personar.apk" ]] || die "could not stage the APK into $SHARE"

LAN_IP="$(/mnt/c/Windows/System32/ipconfig.exe 2>/dev/null \
  | tr -d '\r' \
  | awk '/IPv4/{print $NF}' \
  | grep -E '^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[01])\.' \
  | grep -v '^172\.2[0-9]\.' \
  | head -1)"

if [[ -z "$LAN_IP" ]]; then
  say "Could not find a LAN address (nothing like 192.168.x.x)."
  say "All addresses found:"
  /mnt/c/Windows/System32/ipconfig.exe 2>/dev/null | tr -d '\r' | awk '/IPv4/{print "  " $NF}'
  die "Without a LAN address the phone cannot reach this machine. Check WiFi is connected."
fi

if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":$PORT "; then
  die "Port $PORT is already in use (a previous server still running?).
Stop it, or run again with a different port:  PORT=8888 bash $0"
fi

python3 - "$LAN_IP" "$PORT" "$SHARE" <<'PY'
import sys, qrcode
from qrcode.image.pil import PilImage
ip, port, share = sys.argv[1], sys.argv[2], sys.argv[3]
url = f"http://{ip}:{port}/personar.apk"
img = qrcode.make(url, image_factory=PilImage, box_size=8, border=3)
img.save(f"{share}/qr.png")
print(f"QR encodes: {url}")
PY

APK_MB=$(du -m "$APK" | cut -f1)

say ""
say "  ┌──────────────────────────────────────────────┐"
say "  │  PersonaR is being served on your WiFi       │"
say "  └──────────────────────────────────────────────┘"
say ""
say "    On your PHONE, open:   http://$LAN_IP:$PORT/"
say "    Or scan:               $SHARE/qr.png"
say ""
say "    APK: ${APK_MB} MB, served from app-release.apk"
say "    Phone and PC must be on the same WiFi network."
say ""
say "    Ctrl-C to stop."
say ""

cd "$SHARE" || die "cannot enter $SHARE"
WIN_SHARE="$(wslpath -w "$SHARE")" || die "cannot convert $SHARE to a Windows path"

say "    Serving from the Windows side (WSL is behind a VM switch and is not"
say "    reachable from your phone)."
say ""

exec "$CMD" /c "cd /d $WIN_SHARE && C:\Python314\python.exe -m http.server $PORT --bind 0.0.0.0"
