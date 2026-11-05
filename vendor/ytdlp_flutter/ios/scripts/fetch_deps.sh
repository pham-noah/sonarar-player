#!/bin/sh
# Fetches the iOS build dependencies for ytdlp_flutter. Run from ios/ (the
# podspec's prepare_command does this automatically at `pod install`).
# Idempotent: skips anything already present.
set -e
cd "$(dirname "$0")/.."

PYTHON_SUPPORT_URL="https://github.com/beeware/Python-Apple-support/releases/download/3.13-b14/Python-3.13-iOS-support.b14.tar.gz"
YTDLP_PYZ_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
CACERT_URL="https://curl.se/ca/cacert.pem"

mkdir -p Resources

# 1. Python.xcframework (device + simulator slices, each with its stdlib).
if [ ! -d "Python.xcframework" ]; then
  echo "ytdlp_flutter: downloading Python-Apple-support (~100 MB)..."
  mkdir -p .python-support
  curl -fsSL "$PYTHON_SUPPORT_URL" -o .python-support/support.tar.gz
  tar -xzf .python-support/support.tar.gz -C .python-support
  mv .python-support/Python.xcframework Python.xcframework
  rm -rf .python-support
fi

# 2. yt-dlp zipapp (pure-Python; imported via sys.path, never executed as a
#    downloaded binary). Pinned by download date — re-run with FORCE=1 to bump.
if [ ! -f "Resources/yt-dlp.pyz" ] || [ -n "$FORCE" ]; then
  echo "ytdlp_flutter: downloading yt-dlp zipapp..."
  curl -fsSL "$YTDLP_PYZ_URL" -o Resources/yt-dlp.pyz
fi

# 3. CA bundle for the embedded interpreter's ssl module.
if [ ! -f "Resources/cacert.pem" ] || [ -n "$FORCE" ]; then
  echo "ytdlp_flutter: downloading CA bundle..."
  curl -fsSL "$CACERT_URL" -o Resources/cacert.pem
fi

# 4. The worker script lives at the repo root (shared source of truth).
cp ../python/worker.py Resources/worker.py

echo "ytdlp_flutter: iOS deps ready."
