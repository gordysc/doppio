import ServiceManagement

/// Wraps `SMAppService`, the macOS 13+ API for registering an app to open at login.
///
/// Registering adds Doppio to System Settings › General › Login Items.
/// This only works when running from a real `.app` bundle, not from `swift run`.
enum LoginItem {
    /// Whether Doppio is set to open at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Whether the user must approve the login item in System Settings first.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Turns opening at login on or off.
    ///
    /// - Parameter enabled: `true` to register, `false` to unregister.
    /// - Throws: An error from `SMAppService` if macOS refuses the change,
    ///   for example when the app isn't running from a bundle.
    static func setEnabled(_ enabled: Bool) throws {
        // `throws` in the signature passes errors on to our caller;
        // `try` marks each call that can throw.
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Opens System Settings at the Login Items page.
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
