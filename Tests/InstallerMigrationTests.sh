#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_ROOT="$(mktemp -d "$TASK_ROOT/build/installer-migration.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT
mkdir -p "$FIXTURE_ROOT/Applications"
LEGACY_APP="$FIXTURE_ROOT/Applications/Time Slots.app"
CURRENT_APP="$FIXTURE_ROOT/Applications/Focus Slots.app"

# A fresh install must not create or move any bundle.
bash "$TASK_ROOT/Installer/preinstall" ignored /Applications "$FIXTURE_ROOT"
[ ! -e "$CURRENT_APP" ]

# A matching old app is moved intact, including its files.
mkdir -p "$LEGACY_APP/Contents"
cat > "$LEGACY_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>local.timeslots.app</string></dict></plist>
PLIST
printf '%s' 'legacy-app-file' > "$LEGACY_APP/Contents/sentinel"
bash "$TASK_ROOT/Installer/preinstall" ignored /Applications "$FIXTURE_ROOT"
[ ! -e "$LEGACY_APP" ]
[ "$(cat "$CURRENT_APP/Contents/sentinel")" = legacy-app-file ]

# Repeated installs must preserve an already-existing new bundle.
mkdir -p "$LEGACY_APP/Contents"
cp "$CURRENT_APP/Contents/Info.plist" "$LEGACY_APP/Contents/Info.plist"
bash "$TASK_ROOT/Installer/preinstall" ignored /Applications "$FIXTURE_ROOT"
[ -d "$LEGACY_APP" ]
[ "$(cat "$CURRENT_APP/Contents/sentinel")" = legacy-app-file ]

# An unrelated app with the old filename must not be moved.
mv "$CURRENT_APP" "$FIXTURE_ROOT/existing-focus-app"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier other.app' "$LEGACY_APP/Contents/Info.plist"
bash "$TASK_ROOT/Installer/preinstall" ignored /Applications "$FIXTURE_ROOT"
[ -d "$LEGACY_APP" ]
[ ! -e "$CURRENT_APP" ]
echo 'PASS: installer fresh install, legacy rename, existing destination, unrelated bundle'
