#!/bin/sh
# App-target Xcode build phase for ytdlp_flutter (iOS).
#
# Adapted from BeeWare Python-Apple-support's documented usage
# (https://github.com/beeware/Python-Apple-support/blob/main/USAGE.md):
#  1. Copies the SDK-matching python stdlib out of Python.xcframework into
#     the app bundle as python-stdlib/.
#  2. Converts each binary stdlib module (.so in lib-dynload) into a tiny
#     one-binary framework in Frameworks/ (iOS only loads signed binary
#     modules from there) and leaves a .fwork pointer behind.
#  3. Signs the generated frameworks with the app's identity.
#
# Add as the LAST "Run Script" phase of the Runner target:
#   sh "$PODS_ROOT/../.symlinks/plugins/ytdlp_flutter/ios/scripts/install_python_stdlib.sh"
# and disable "Based on dependency analysis" for the phase.
set -e

PLUGIN_IOS_DIR="${YTDLP_FLUTTER_IOS_DIR:-$PODS_ROOT/../.symlinks/plugins/ytdlp_flutter/ios}"
XCFRAMEWORK="$PLUGIN_IOS_DIR/Python.xcframework"

if [ ! -d "$XCFRAMEWORK" ]; then
    echo "error: $XCFRAMEWORK not found — run 'pod install' first (its prepare_command fetches it)."
    exit 1
fi

# Layout of Python-Apple-support 3.13-b14: the pure-Python stdlib is shared
# at Python.xcframework/lib/pythonX.Y; the binary modules (lib-dynload) live
# per slice and per arch under <slice>/lib-<arch>/pythonX.Y/lib-dynload.
PYTHON_DIR=$(basename "$(ls -d "$XCFRAMEWORK"/lib/python3.* | head -1)")
BUILD_ARCH=$(echo "$ARCHS" | cut -d " " -f 1)
if [ "$EFFECTIVE_PLATFORM_NAME" = "-iphonesimulator" ]; then
    echo "Installing Python stdlib for the iOS simulator ($BUILD_ARCH)"
    SLICE="$XCFRAMEWORK/ios-arm64_x86_64-simulator"
    PLATFORM_TAG="$BUILD_ARCH-iphonesimulator"
else
    echo "Installing Python stdlib for iOS devices ($BUILD_ARCH)"
    SLICE="$XCFRAMEWORK/ios-arm64"
    PLATFORM_TAG="$BUILD_ARCH-iphoneos"
fi
DYNLOAD="$SLICE/lib-$BUILD_ARCH/$PYTHON_DIR/lib-dynload"

mkdir -p "$CODESIGNING_FOLDER_PATH/python-stdlib"
# Exclude CPython self-test suite and desktop/dev tooling (~39 MB) — never
# imported by yt-dlp. The upstream macOS Python.framework already ships
# without test/; the iOS xcframework keeps it, so filter it out here.
rsync -au --delete --delete-excluded \
    --exclude 'test/' --exclude 'idlelib/' --exclude 'ensurepip/' \
    --exclude 'tkinter/' --exclude 'pydoc_data/' --exclude 'turtledemo/' \
    "$XCFRAMEWORK/lib/$PYTHON_DIR/" \
    "$CODESIGNING_FOLDER_PATH/python-stdlib/"
mkdir -p "$CODESIGNING_FOLDER_PATH/python-stdlib/lib-dynload"
rsync -au --delete "$DYNLOAD/" \
    "$CODESIGNING_FOLDER_PATH/python-stdlib/lib-dynload/"
# sysconfig needs the per-platform _sysconfigdata module (the rest of
# platform-config is cross-compilation tooling, not needed at runtime).
cp "$SLICE/platform-config/$PLATFORM_TAG/"_sysconfigdata__*.py \
    "$CODESIGNING_FOLDER_PATH/python-stdlib/"

# The worker script, yt-dlp zipapp, and CA bundle go into the app bundle
# root: shipping them as pod resources puts them at the (shallow) framework
# root, where App Store validation rejects script-like files as unsigned
# code (ITMS-90035). App-root .py/.pyz files pass (python-stdlib proves it).
cp "$PLUGIN_IOS_DIR/Resources/worker.py" \
   "$PLUGIN_IOS_DIR/Resources/yt-dlp.pyz" \
   "$PLUGIN_IOS_DIR/Resources/cacert.pem" \
   "$CODESIGNING_FOLDER_PATH/"

install_dylib () {
    INSTALL_BASE=$1
    FULL_EXT=$2
    EXT=$(basename "$FULL_EXT")
    RELATIVE_EXT=${FULL_EXT#"$CODESIGNING_FOLDER_PATH"/}
    PYTHON_EXT=${RELATIVE_EXT/$INSTALL_BASE/}
    FULL_MODULE_NAME=$(echo "$PYTHON_EXT" | cut -d "." -f 1 | tr "/" ".")
    FRAMEWORK_BUNDLE_ID=$(echo "$PRODUCT_BUNDLE_IDENTIFIER.$FULL_MODULE_NAME" | tr "_" "-")
    FRAMEWORK_FOLDER="Frameworks/$FULL_MODULE_NAME.framework"

    if [ ! -d "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER" ]; then
        mkdir -p "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER"
        cat > "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$FULL_MODULE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$FRAMEWORK_BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$FULL_MODULE_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
    <key>MinimumOSVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF
    fi

    mv "$FULL_EXT" "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME"
    echo "$FRAMEWORK_FOLDER/$FULL_MODULE_NAME" > "${FULL_EXT%.so}.fwork"
    echo "${RELATIVE_EXT%.so}.fwork" > "$CODESIGNING_FOLDER_PATH/$FRAMEWORK_FOLDER/$FULL_MODULE_NAME.origin"
}

echo "Installing Python stdlib binary modules as frameworks..."
find "$CODESIGNING_FOLDER_PATH/python-stdlib/lib-dynload" -name "*.so" | while read -r FULL_EXT; do
    install_dylib python-stdlib/lib-dynload/ "$FULL_EXT"
done

# Simulator builds may have no signing identity; unsigned modules load fine
# there, so only sign when an identity exists (required on device).
if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    echo "Signing binary-module frameworks as $EXPANDED_CODE_SIGN_IDENTITY_NAME ($EXPANDED_CODE_SIGN_IDENTITY)..."
    find "$CODESIGNING_FOLDER_PATH/Frameworks" -name "*.framework" -exec \
        /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
        ${OTHER_CODE_SIGN_FLAGS:-} -o runtime --timestamp=none \
        --preserve-metadata=identifier,entitlements,flags \
        --generate-entitlement-der {} \;
else
    echo "No code-sign identity (simulator build) — skipping framework signing."
fi

echo "ytdlp_flutter: python stdlib installed."
