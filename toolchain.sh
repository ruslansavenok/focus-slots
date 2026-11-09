# Sourced by build/test scripts. Keep build caches inside the project.
SWIFT_COMPILER="$(xcrun --find swiftc)"
SWIFT_FLAGS=(-module-cache-path "$BUILD/ModuleCache")
SWIFT_INCLUDE="$(dirname "$(dirname "$SWIFT_COMPILER")")/include/swift"
# Some upgraded Command Line Tools retain two definitions of SwiftBridging.
# Hide only the legacy duplicate in this build's virtual filesystem.
if [ -f "$SWIFT_INCLUDE/module.modulemap" ] && [ -f "$SWIFT_INCLUDE/bridging.modulemap" ]; then
    : > "$BUILD/empty.modulemap"
    cat > "$BUILD/toolchain-overlay.json" <<JSON
{"version":0,"roots":[{"type":"file","name":"$SWIFT_INCLUDE/module.modulemap","external-contents":"$BUILD/empty.modulemap"}]}
JSON
    SWIFT_FLAGS+=(-vfsoverlay "$BUILD/toolchain-overlay.json")
fi

# Typecheck the actual SwiftUI feature that newer SDKs implement as a macro.
# A directory/version check alone cannot tell whether its plugin is installed.
cat > "$BUILD/SDKProbe.swift" <<'SWIFT'
import SwiftUI
struct SDKProbe: View {
    @State private var value = false
    var body: some View { Text(value ? "Yes" : "No") }
}
SWIFT
sdk_works() {
    "$SWIFT_COMPILER" "${SWIFT_FLAGS[@]}" -sdk "$1" \
        -target "$(uname -m)-apple-macosx13.0" -typecheck "$BUILD/SDKProbe.swift" \
        > "$BUILD/sdk-probe.log" 2>&1
}
sdk_candidates() {
    local candidate version major minor patch
    for candidate in "$1"/MacOSX[0-9]*.sdk; do
        [ -d "$candidate" ] || continue
        version="${candidate##*/MacOSX}"
        version="${version%.sdk}"
        IFS=. read -r major minor patch <<< "$version"
        case "${major}${minor}${patch}" in *[!0-9]*|'') continue ;; esac
        printf '%d\t%s\n' "$((10#${major} * 1000000 + 10#${minor:-0} * 1000 + 10#${patch:-0}))" "$candidate"
    done | sort -rn | cut -f2-
}

if [ -n "${SDKROOT:-}" ]; then
    SDK="$SDKROOT"
    if [ ! -d "$SDK" ]; then
        echo "SDKROOT must point to an installed macOS SDK directory: $SDK" >&2
        exit 1
    fi
    if ! sdk_works "$SDK"; then
        cat "$BUILD/sdk-probe.log" >&2
        echo "SDKROOT cannot compile SwiftUI @State with the selected compiler: $SDK" >&2
        echo 'Choose a compatible SDK (for example MacOSX26.5.sdk), or use full Xcode with the required SwiftUI macro plugin.' >&2
        exit 1
    fi
else
    DEFAULT_SDK="$(xcrun --sdk macosx --show-sdk-path)"
    SDK="$DEFAULT_SDK"
    if ! sdk_works "$SDK"; then
        cp "$BUILD/sdk-probe.log" "$BUILD/default-sdk-probe.log"
        SDK=''
        while IFS= read -r CANDIDATE; do
            [ "$CANDIDATE" != "$DEFAULT_SDK" ] || continue
            if sdk_works "$CANDIDATE"; then SDK="$CANDIDATE"; break; fi
        done < <(sdk_candidates "$(dirname "$DEFAULT_SDK")")
        if [ -z "$SDK" ]; then
            cat "$BUILD/default-sdk-probe.log" >&2
            echo 'No installed macOS SDK can compile SwiftUI @State with the selected compiler.' >&2
            echo 'Set SDKROOT to a compatible SDK directory, or install full Xcode with the required SwiftUI macro plugin.' >&2
            exit 1
        fi
        echo "Default SDK failed the SwiftUI check; using $SDK" >&2
    fi
fi
SWIFT_FLAGS+=(-sdk "$SDK")
echo "Using SDK: $SDK"
