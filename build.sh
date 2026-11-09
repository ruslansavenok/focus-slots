#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$TASK_ROOT"
BUILD="$TASK_ROOT/build"
APP="$BUILD/Focus Slots.app"
mkdir -p "$BUILD" "$TASK_ROOT/dist"
source "$TASK_ROOT/toolchain.sh"
source "$TASK_ROOT/version.sh"
echo "Testing timer behavior…"
swiftc "${SWIFT_FLAGS[@]}" Sources/SlotState.swift Tests/SlotStateTests.swift -o "$BUILD/SlotStateTests"
"$BUILD/SlotStateTests"
echo "Creating app assets…"
swiftc "${SWIFT_FLAGS[@]}" Resources/make-assets.swift -o "$BUILD/make-assets"
"$BUILD/make-assets" "$BUILD"
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$BUILD/AppIcon.icns"
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
for ARCH in x86_64 arm64; do
    echo "Building $ARCH…"
    swiftc -O "${SWIFT_FLAGS[@]}" -target "$ARCH-apple-macosx13.0" \
        Sources/SlotState.swift Sources/CompletionSound.swift Sources/FocusSlots.swift "$BUILD/AppVersion.swift" \
        -o "$BUILD/FocusSlots-$ARCH" -framework AppKit -framework SwiftUI -framework AVFoundation
done
lipo -create "$BUILD/FocusSlots-x86_64" "$BUILD/FocusSlots-arm64" -output "$APP/Contents/MacOS/FocusSlots"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
echo "Creating drag-to-Applications disk image…"
DMG_ROOT="$(mktemp -d "$BUILD/dmg-root.XXXXXX")"
chmod 755 "$DMG_ROOT"
trap 'rm -rf "$DMG_ROOT"' EXIT
ditto "$APP" "$DMG_ROOT/Focus Slots.app"
ln -s /Applications "$DMG_ROOT/Applications"
DMG="$TASK_ROOT/dist/FocusSlots-$APP_VERSION.dmg"
hdiutil create -volname "Focus Slots" -srcfolder "$DMG_ROOT" \
    -fs HFS+ -format UDZO -ov "$DMG"
bash Tests/DMGTests.sh "$DMG" "$APP_VERSION"
echo "Built: $DMG"
