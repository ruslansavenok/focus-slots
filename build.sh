#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$TASK_ROOT"
case "${1:-}" in
    '') ARCHS=("$(uname -m)") ;;
    --universal) ARCHS=(x86_64 arm64) ;;
    --help|-h) echo 'Usage: bash build.sh [--universal]'; exit 0 ;;
    *) echo 'Usage: bash build.sh [--universal]' >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then
    echo 'Usage: bash build.sh [--universal]' >&2
    exit 1
fi
BUILD="$TASK_ROOT/build"
APP="$BUILD/Focus Slots.app"
mkdir -p "$BUILD"
source "$TASK_ROOT/toolchain.sh"
source "$TASK_ROOT/version.sh"
echo 'Testing timer behavior...'
"$SWIFT_COMPILER" "${SWIFT_FLAGS[@]}" Sources/SlotState.swift Tests/SlotStateTests.swift -o "$BUILD/SlotStateTests"
"$BUILD/SlotStateTests"
echo 'Creating app assets...'
"$SWIFT_COMPILER" "${SWIFT_FLAGS[@]}" Resources/make-assets.swift -o "$BUILD/make-assets"
"$BUILD/make-assets" "$BUILD"
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$BUILD/AppIcon.icns"
# Rebuild the bundle so no stale resources or signatures survive an update.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/AppIcon.icns" "$BUILD/completion.wav" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Focus Slots</string>
<key>CFBundleDisplayName</key><string>Focus Slots</string>
<key>CFBundleIdentifier</key><string>local.timeslots.app</string>
<key>CFBundleExecutable</key><string>FocusSlots</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>CFBundleVersion</key><string>$APP_BUILD</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>Focus Slots — a simple personal focus timer.</string>
</dict></plist>
PLIST
SLICES=()
for ARCH in "${ARCHS[@]}"; do
    case "$ARCH" in x86_64|arm64) ;; *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; esac
    echo "Building ${ARCH}..."
    "$SWIFT_COMPILER" -O "${SWIFT_FLAGS[@]}" -target "${ARCH}-apple-macosx13.0" \
        Sources/SlotState.swift Sources/CompletionSound.swift Sources/FocusSlots.swift "$BUILD/AppVersion.swift" \
        -o "$BUILD/FocusSlots-${ARCH}" -framework AppKit -framework SwiftUI -framework AVFoundation
    SLICES+=("$BUILD/FocusSlots-${ARCH}")
done
if [ "${#SLICES[@]}" -eq 1 ]; then
    cp "${SLICES[0]}" "$APP/Contents/MacOS/FocusSlots"
else
    lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/FocusSlots"
fi
# Some lipo versions accept only one architecture per verification call.
for ARCH in "${ARCHS[@]}"; do
    lipo "$APP/Contents/MacOS/FocusSlots" -verify_arch "$ARCH"
done
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
echo "Built: $APP"
echo 'To install and launch: bash install.sh'
