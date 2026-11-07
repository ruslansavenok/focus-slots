# Sourced by build/test scripts. Keep build caches inside the project.
SDK="$(xcrun --show-sdk-path)"
SWIFT_FLAGS=(-sdk "$SDK" -module-cache-path "$BUILD/ModuleCache")
SWIFT_INCLUDE="$(dirname "$(dirname "$(xcrun --find swiftc)")")/include/swift"
# Some upgraded Command Line Tools retain two definitions of SwiftBridging.
# Hide only the legacy duplicate in this build's virtual filesystem; do not
# change the installed toolchain or require a reinstall.
if [ -f "$SWIFT_INCLUDE/module.modulemap" ] && [ -f "$SWIFT_INCLUDE/bridging.modulemap" ]; then
    : > "$BUILD/empty.modulemap"
    cat > "$BUILD/toolchain-overlay.json" <<JSON
{"version":0,"roots":[{"type":"file","name":"$SWIFT_INCLUDE/module.modulemap","external-contents":"$BUILD/empty.modulemap"}]}
JSON
    SWIFT_FLAGS+=(-vfsoverlay "$BUILD/toolchain-overlay.json")
fi
