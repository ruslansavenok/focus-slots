# Single release definition for the app binary and bundle metadata.
APP_VERSION="1.0.11"
APP_BUILD="12"
cat > "$BUILD/AppVersion.swift" <<SWIFT
enum AppVersion {
    static let version = "$APP_VERSION"
    static let build = "$APP_BUILD"
    static let display = "Version $APP_VERSION"
}
SWIFT
