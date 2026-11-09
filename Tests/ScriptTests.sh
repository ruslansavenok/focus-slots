#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/focus-slots-tests.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd)"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/SDKs" "$TEST_ROOT/probe-build"
export TEST_ROOT
export PATH="$TEST_ROOT/bin:$PATH"
for VERSION in 27.0 26.5 26.4; do mkdir "$TEST_ROOT/SDKs/MacOSX${VERSION}.sdk"; done
cat > "$TEST_ROOT/bin/xcrun" <<'SH'
#!/bin/bash
if [ "$1" = --find ]; then
    echo "$TEST_ROOT/bin/swiftc"
else
    echo "$TEST_ROOT/SDKs/MacOSX27.0.sdk"
fi
SH
cat > "$TEST_ROOT/bin/swiftc" <<'SH'
#!/bin/bash
while [ "$#" -gt 0 ]; do
    if [ "$1" = -sdk ]; then SDK="$2"; shift; fi
    shift
done
if [ "${TEST_ALL_SDKS_FAIL:-0}" = 1 ] || { [ "${SDK##*/}" = MacOSX27.0.sdk ] && [ "${TEST_PLUGIN_INSTALLED:-0}" != 1 ]; }; then
    echo "SwiftUIMacros.StateMacro plugin not found" >&2
    exit 1
fi
SH
chmod +x "$TEST_ROOT/bin/xcrun" "$TEST_ROOT/bin/swiftc"
probe() {
    BUILD="$TEST_ROOT/probe-build" bash -eu -c 'source "$1"; echo "SELECTED=$SDK"' _ "$TASK_ROOT/toolchain.sh"
}
unset SDKROOT
probe > "$TEST_ROOT/probe.out" 2>&1
grep -F "SELECTED=$TEST_ROOT/SDKs/MacOSX26.5.sdk" "$TEST_ROOT/probe.out" >/dev/null
mkdir "$TEST_ROOT/SDKs/MacOSX26.10.sdk"
probe > "$TEST_ROOT/probe.out" 2>&1
grep -F "SELECTED=$TEST_ROOT/SDKs/MacOSX26.10.sdk" "$TEST_ROOT/probe.out" >/dev/null
TEST_PLUGIN_INSTALLED=1 probe > "$TEST_ROOT/probe.out" 2>&1
grep -F "SELECTED=$TEST_ROOT/SDKs/MacOSX27.0.sdk" "$TEST_ROOT/probe.out" >/dev/null
SDKROOT="$TEST_ROOT/SDKs/MacOSX26.4.sdk" probe > "$TEST_ROOT/probe.out" 2>&1
grep -F "SELECTED=$TEST_ROOT/SDKs/MacOSX26.4.sdk" "$TEST_ROOT/probe.out" >/dev/null
if SDKROOT="$TEST_ROOT/SDKs/MacOSX27.0.sdk" probe > "$TEST_ROOT/probe.out" 2>&1; then
    echo 'FAIL: an incompatible explicit SDKROOT was silently ignored' >&2; exit 1
fi
grep -F 'SDKROOT cannot compile' "$TEST_ROOT/probe.out" >/dev/null
if SDKROOT="$TEST_ROOT/missing.sdk" probe > "$TEST_ROOT/probe.out" 2>&1; then
    echo 'FAIL: nonexistent SDKROOT was accepted' >&2; exit 1
fi
if TEST_ALL_SDKS_FAIL=1 probe > "$TEST_ROOT/probe.out" 2>&1; then
    echo 'FAIL: missing compatible SDK was accepted' >&2; exit 1
fi
grep -F 'No installed macOS SDK' "$TEST_ROOT/probe.out" >/dev/null
echo 'PASS: SDK fallback, newest compatible SDK, plugin-present default, SDKROOT override and actionable failures'

# Exercise the real installer with an already-built app in a disposable
# project. Mock only build/process/launch commands: never stop a user's app.
FIXTURE="$TEST_ROOT/project with spaces"
mkdir -p "$FIXTURE/build"
cp "$TASK_ROOT/install.sh" "$FIXTURE/install.sh"
ditto "$TASK_ROOT/build/Focus Slots.app" "$FIXTURE/build/Focus Slots.app"
cat > "$FIXTURE/build.sh" <<'SH'
#!/bin/bash
echo "build $*" >> "$TEST_ROOT/actions"
exit "${TEST_BUILD_EXIT:-0}"
SH
cat > "$TEST_ROOT/bin/pgrep" <<'SH'
#!/bin/bash
[ -f "$TEST_ROOT/running" ]
SH
cat > "$TEST_ROOT/bin/pkill" <<'SH'
#!/bin/bash
echo "quit $*" >> "$TEST_ROOT/actions"
rm -f "$TEST_ROOT/running"
SH
cat > "$TEST_ROOT/bin/open" <<'SH'
#!/bin/bash
echo "open $*" >> "$TEST_ROOT/actions"
exit "${TEST_OPEN_EXIT:-0}"
SH
cat > "$TEST_ROOT/bin/mv" <<'SH'
#!/bin/bash
if [ "${TEST_MOVE_FAIL:-0}" = 1 ]; then
    case "$1" in */.focus-slots-install.*/'Focus Slots.app') exit 1 ;; esac
fi
exec /bin/mv "$@"
SH
chmod +x "$TEST_ROOT/bin/pgrep" "$TEST_ROOT/bin/pkill" "$TEST_ROOT/bin/open" "$TEST_ROOT/bin/mv"
export INSTALL_DIR="$TEST_ROOT/Personal Applications"
bash "$FIXTURE/install.sh" --universal
DEST="$INSTALL_DIR/Focus Slots.app"
codesign --verify --deep --strict "$DEST"
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DEST/Contents/Info.plist")" = local.timeslots.app ]
grep -F 'build --universal' "$TEST_ROOT/actions" >/dev/null
grep -F "open $DEST" "$TEST_ROOT/actions" >/dev/null

touch "$DEST/Contents/Resources/stale-resource" "$TEST_ROOT/running"
codesign --force --sign - --timestamp=none "$DEST"
bash "$FIXTURE/install.sh"
[ ! -e "$DEST/Contents/Resources/stale-resource" ]
[ ! -e "$TEST_ROOT/running" ]
[ -e ]
grep -F "quit -TERM -u $(id -u) -x FocusSlots" "$TEST_ROOT/actions" >/dev/null
[ "$(tail -1 "$TEST_ROOT/actions")" = "open $DEST" ]

touch "$DEST/Contents/Resources/previous-version" "$TEST_ROOT/running"
codesign --force --sign - --timestamp=none "$DEST"
if TEST_BUILD_EXIT=1 bash "$FIXTURE/install.sh"; then
    echo 'FAIL: installer continued after a failed build' >&2; exit 1
fi
[ -e "$DEST/Contents/Resources/previous-version" ] && [ -e "$TEST_ROOT/running" ]
if TEST_MOVE_FAIL=1 bash "$FIXTURE/install.sh"; then
    echo 'FAIL: replacement failure was ignored' >&2; exit 1
fi
[ -e "$DEST/Contents/Resources/previous-version" ]
codesign --verify --deep --strict "$DEST"

# A link or unrelated destination must not be replaced.
mkdir -p "$TEST_ROOT/unrelated/Focus Slots.app"
touch "$TEST_ROOT/unrelated/Focus Slots.app/keep"
if INSTALL_DIR="$TEST_ROOT/unrelated" bash "$FIXTURE/install.sh"; then
    echo 'FAIL: installer replaced an unrelated destination' >&2; exit 1
fi
[ -e "$TEST_ROOT/unrelated/Focus Slots.app/keep" ]
mkdir "$TEST_ROOT/linked"
ln -s "$DEST" "$TEST_ROOT/linked/Focus Slots.app"
if INSTALL_DIR="$TEST_ROOT/linked" bash "$FIXTURE/install.sh"; then
    echo 'FAIL: installer replaced a symbolic link' >&2; exit 1
fi
[ -L "$TEST_ROOT/linked/Focus Slots.app" ]
if TEST_OPEN_EXIT=1 bash "$FIXTURE/install.sh" > "$TEST_ROOT/open.out" 2>&1; then
    echo 'FAIL: launch failure was ignored' >&2; exit 1
fi
grep -F 'installed but could not be opened' "$TEST_ROOT/open.out" >/dev/null
codesign --verify --deep --strict "$DEST"
echo 'PASS: custom install path with spaces, replacement, quit before launch, build failure safety, rollback, unrelated destinations and launch failure'
