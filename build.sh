#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$TASK_ROOT"
BUILD="$TASK_ROOT/build"
APP="$BUILD/Focus Slots.app"
mkdir -p "$BUILD" "$TASK_ROOT/dist"
source "$TASK_ROOT/toolchain.sh"
source "$TASK_ROOT/version.sh"
echo "Testing installer rename migration…"
bash Tests/InstallerMigrationTests.sh
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
echo "Packaging installer…"
# Always stage into a fresh directory so a renamed app cannot leave an old
# app bundle in the installer payload.
PACKAGE_ROOT="$(mktemp -d "$BUILD/package-root.XXXXXX")"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT
ditto "$APP" "$PACKAGE_ROOT/Focus Slots.app"
pkgbuild --analyze --root "$PACKAGE_ROOT" "$BUILD/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$BUILD/components.plist"
pkgbuild --root "$PACKAGE_ROOT" --component-plist "$BUILD/components.plist" \
    --scripts "$TASK_ROOT/Installer" \
    --identifier local.timeslots.installer --version "$APP_VERSION" \
    --install-location /Applications "$TASK_ROOT/dist/FocusSlots-$APP_VERSION.pkg"
echo "Built: $TASK_ROOT/dist/FocusSlots-$APP_VERSION.pkg"
