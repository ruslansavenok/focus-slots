# Single release definition for the app binary, bundle metadata, and disk image.
APP_VERSION="1.0.10"
APP_BUILD="11"
cat > "$BUILD/AppVersion.swift" <<SWIFT
enum AppVersion {
    static let version = "$APP_VERSION"
    static let build = "$APP_BUILD"
    static let display = "Version $APP_VERSION"
}
SWIFT
