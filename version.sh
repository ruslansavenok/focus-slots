# Single release definition for the app binary, bundle metadata, and installer.
APP_VERSION="1.0.8"
APP_BUILD="9"
cat > "$BUILD/AppVersion.swift" <<SWIFT
enum AppVersion {
    static let version = "$APP_VERSION"
    static let build = "$APP_BUILD"
    static let display = "Version $APP_VERSION"
}
SWIFT
