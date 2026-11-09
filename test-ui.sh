#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$TASK_ROOT"
BUILD="$TASK_ROOT/build"
mkdir -p "$BUILD"
source "$TASK_ROOT/toolchain.sh"
source "$TASK_ROOT/version.sh"
TEST_APP="$BUILD/Test Harness.app"
mkdir -p "$TEST_APP/Contents/MacOS" "$TEST_APP/Contents/Resources"
cp "$BUILD/completion.wav" "$TEST_APP/Contents/Resources/"
cat > "$TEST_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.timeslots.tests</string>
<key>CFBundleExecutable</key><string>AppUITests</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
"$SWIFT_COMPILER" "${SWIFT_FLAGS[@]}" -target "$(uname -m)-apple-macosx13.0" -D TIME_SLOTS_UI_TEST Sources/SlotState.swift Sources/CompletionSound.swift Sources/FocusSlots.swift "$BUILD/AppVersion.swift" Tests/AppUITests.swift -o "$TEST_APP/Contents/MacOS/AppUITests" -framework AppKit -framework SwiftUI -framework AVFoundation
"$TEST_APP/Contents/MacOS/AppUITests" "$BUILD"
