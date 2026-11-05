#!/bin/sh
# Fetches the macOS build dependencies for ytdlp_flutter. Run from macos/
# (the podspec's prepare_command does this automatically at `pod install`).
# Idempotent; re-run with FORCE=1 to bump yt-dlp / the CA bundle.
set -e
cd "$(dirname "$0")/.."

PYTHON_SUPPORT_URL="https://github.com/beeware/Python-Apple-support/releases/download/3.13-b14/Python-3.13-macOS-support.b14.tar.gz"
YTDLP_PYZ_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
CACERT_URL="https://curl.se/ca/cacert.pem"

mkdir -p Resources

# 1. Python.xcframework (universal macOS slice with the stdlib).
if [ ! -d "Python.xcframework" ]; then
  echo "ytdlp_flutter: downloading Python-Apple-support for macOS (~50 MB)..."
  mkdir -p .python-support
  curl -fsSL "$PYTHON_SUPPORT_URL" -o .python-support/support.tar.gz
  tar -xzf .python-support/support.tar.gz -C .python-support
  mv .python-support/Python.xcframework Python.xcframework
  rm -rf .python-support
fi

# Prune build tooling from the framework (runs on every invocation so
# previously fetched copies get cleaned too). config-*/python.o is a plain
# Mach-O object file that App Store export re-signing chokes on
# ("operation inapplicable or not supported for this type of code");
# test/ and __pycache__ are dead weight at runtime.
STDLIB="Python.xcframework/macos-arm64_x86_64/Python.framework/Versions/3.13/lib/python3.13"
rm -rf "$STDLIB"/config-* "$STDLIB/test" "$STDLIB/idlelib" "$STDLIB/turtledemo"
find "Python.xcframework" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true

# 2. yt-dlp zipapp (pure-Python; imported via sys.path).
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

echo "ytdlp_flutter: macOS deps ready."
