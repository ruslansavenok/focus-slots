#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="${1:?Usage: bash Tests/DMGTests.sh image.dmg version}"
EXPECTED_VERSION="${2:?Expected version is required}"
mkdir -p "$TASK_ROOT/build"
CHECK_ROOT="$(mktemp -d "$TASK_ROOT/build/dmg-check.XXXXXX")"
MOUNT_POINT="$CHECK_ROOT/mounted"
MOUNTED=0
cleanup() {
    if [ "$MOUNTED" -eq 1 ]; then
        hdiutil detach "$MOUNT_POINT" -quiet
    fi
    rm -rf "$CHECK_ROOT"
}
trap cleanup EXIT
mkdir -p "$MOUNT_POINT" "$CHECK_ROOT/Applications"
hdiutil verify "$DMG" -quiet
hdiutil attach "$DMG" -mountpoint "$MOUNT_POINT" -readonly -nobrowse -noautoopen -quiet
MOUNTED=1

# The image must remain readable when mounted by a different Mac account.
[ "$(stat -f '%OLp' "$MOUNT_POINT")" = 755 ]

[ -L "$MOUNT_POINT/Applications" ]
[ "$(readlink "$MOUNT_POINT/Applications")" = /Applications ]
[ -d "$MOUNT_POINT/Focus Slots.app" ]
for ITEM in "$MOUNT_POINT"/*; do
    case "$(basename "$ITEM")" in
        'Focus Slots.app'|Applications) ;;
        *) echo "Unexpected item in disk image: $ITEM" >&2; exit 1 ;;
    esac
done
codesign --verify --deep --strict "$MOUNT_POINT/Focus Slots.app"

# Simulate dragging the whole app into an Applications folder, without
# touching the user's installed app or running any installer scripts.
ditto "$MOUNT_POINT/Focus Slots.app" "$CHECK_ROOT/Applications/Focus Slots.app"
COPIED_APP="$CHECK_ROOT/Applications/Focus Slots.app"
codesign --verify --deep --strict "$COPIED_APP"
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$COPIED_APP/Contents/Info.plist")" = local.timeslots.app ]
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleName' "$COPIED_APP/Contents/Info.plist")" = 'Focus Slots' ]
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$COPIED_APP/Contents/Info.plist")" = "$EXPECTED_VERSION" ]
[ -x "$COPIED_APP/Contents/MacOS/FocusSlots" ]
lipo "$COPIED_APP/Contents/MacOS/FocusSlots" -verify_arch x86_64 arm64
echo 'PASS: DMG integrity, readable volume, Applications shortcut, app-only contents, copy installation, signatures, original app identity, version, and universal binary'
