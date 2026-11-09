#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
    ''|--universal) ;;
    --help|-h) echo 'Usage: bash install.sh [--universal]'; echo 'INSTALL_DIR defaults to ~/Applications.'; exit 0 ;;
    *) echo 'Usage: bash install.sh [--universal]' >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then echo 'Usage: bash install.sh [--universal]' >&2; exit 1; fi

# Build and verify before stopping or replacing a working installed copy.
bash "$TASK_ROOT/build.sh" "$@"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
mkdir -p "$INSTALL_DIR"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
DEST="$INSTALL_DIR/Focus Slots.app"
SOURCE="$TASK_ROOT/build/Focus Slots.app"
if [ "$INSTALL_DIR" = "$(cd "$TASK_ROOT/build" && pwd)" ]; then
    echo 'INSTALL_DIR must be different from the build directory.' >&2
    exit 1
fi
if [ -L "$DEST" ] || { [ -e "$DEST" ] && [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DEST/Contents/Info.plist" 2>/dev/null || true)" != local.timeslots.app ]; }; then
    echo "Refusing to replace an unrelated file, app, or symbolic link: $DEST" >&2
    exit 1
fi
STAGE="$(mktemp -d "$INSTALL_DIR/.focus-slots-install.XXXXXX")"
BACKUP_MOVED=0
INSTALLED=0
cleanup() {
    if [ "$BACKUP_MOVED" -eq 1 ] && [ "$INSTALLED" -eq 0 ]; then
        # Retain the backup and report its location if restoring it fails.
        if ! mv "$STAGE/Previous.app" "$DEST"; then
            echo "Previous app retained at: $STAGE/Previous.app" >&2
            return
        fi
    fi
    rm -rf "$STAGE"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
ditto "$SOURCE" "$STAGE/Focus Slots.app"
codesign --verify --deep --strict "$STAGE/Focus Slots.app"

# State is persisted on every timer/settings change. Terminate only this
# user's copies, and wait for exit so opening the new copy cannot reuse one.
USER_ID="$(id -u)"
if pgrep -u "$USER_ID" -x FocusSlots >/dev/null; then
    pkill -TERM -u "$USER_ID" -x FocusSlots || [ "$?" -eq 1 ]
    ATTEMPTS=0
    while pgrep -u "$USER_ID" -x FocusSlots >/dev/null; do
        if [ "$ATTEMPTS" -ge 50 ]; then
            echo 'Focus Slots is still running. Quit it and run the installer again.' >&2
            exit 1
        fi
        sleep 0.1
        ATTEMPTS=$((ATTEMPTS + 1))
    done
fi
if [ -e "$DEST" ]; then
    mv "$DEST" "$STAGE/Previous.app"
    BACKUP_MOVED=1
fi
mv "$STAGE/Focus Slots.app" "$DEST"
INSTALLED=1
echo "Installed: $DEST"
if ! open "$DEST"; then
    echo "The app was installed but could not be opened. Try opening it from $INSTALL_DIR and check your organisation's app policy." >&2
    exit 1
fi
