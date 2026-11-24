import SwiftUI

/// The standalone Doppio window: the same controls as the popover, plus app settings.
struct MainWindowView: View {
    /// The shared model.
    let model: AppModel

    /// Controls on top, settings below.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ControlPanel(model: model)
            Divider()
            SettingsSection(model: model)
        }
        .padding(20)
        .frame(width: 380)
        // Let the window size itself to fit the content.
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// App-level settings: login item, launch behavior, and where the app shows.
private struct SettingsSection: View {
    /// The shared model.
    let model: AppModel

    /// Whether the login item is on, as last read from macOS.
    ///
    /// `@State` is storage that SwiftUI keeps for this view across `body`
    /// re-evaluations. The view `struct` itself is recreated all the time, so
    /// a plain `var` here would be reset. `private` because `@State` belongs
    /// to this view alone.
    @State private var launchAtLogin = LoginItem.isEnabled

    /// Whether macOS wants the user to approve the login item.
    @State private var needsApproval = LoginItem.needsApproval

    /// The last login-item error, shown under the toggle.
    @State private var loginError: String?

    /// The settings toggles.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SETTINGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            // `$launchAtLogin` (with `$`) is the *binding* to the `@State`
            // value: a read/write handle the toggle uses to change it.
            Toggle("Open Doppio at login", isOn: $launchAtLogin)
                // `onChange` runs after the value changes; here, it applies the
                // new value to macOS.
                .onChange(of: launchAtLogin) { _, enabled in
                    updateLoginItem(enabled)
                }
            if needsApproval {
                HStack {
                    Text("Approve Doppio in Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") { LoginItem.openSystemSettings() }
                        .controlSize(.small)
                }
            }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }

            Toggle("Keep the Mac awake when Doppio opens", isOn: Binding(
                get: { model.prefs.activateOnLaunch },
                set: { model.prefs.activateOnLaunch = $0 }
            ))

            Toggle("Show in the menu bar", isOn: Binding(
                get: { model.prefs.showMenuBarIcon },
                set: { model.setShowMenuBarIcon($0) }
            ))

            Toggle("Show the remaining time in the menu bar", isOn: Binding(
                get: { model.prefs.showCountdownInMenuBar },
                set: { model.prefs.showCountdownInMenuBar = $0 }
            ))
            .disabled(!model.prefs.showMenuBarIcon)
            // Indent to show it depends on the toggle above.
            .padding(.leading, 20)

            Toggle("Show in the Dock", isOn: Binding(
                get: { model.prefs.showDockIcon },
                set: { model.setShowDockIcon($0) }
            ))
            // With no menu bar icon, the Dock icon is the only way back in.
            .disabled(!model.prefs.showMenuBarIcon)
        }
        .toggleStyle(.checkbox)
        // Re-read the login item state whenever the window shows, in case it
        // was changed in System Settings meanwhile.
        .onAppear(perform: refreshLoginItem)
    }

    /// Applies the login toggle to macOS, and resets the toggle if that fails.
    ///
    /// - Parameter enabled: Whether Doppio should open at login.
    private func updateLoginItem(_ enabled: Bool) {
        // Skip if the toggle already matches macOS. This happens when
        // `refreshLoginItem` itself sets `launchAtLogin`, which fires `onChange` again.
        // "Awaiting approval" counts as registered, so turning it off still unregisters.
        guard enabled != (LoginItem.isEnabled || LoginItem.needsApproval) else { return }
        do {
            try LoginItem.setEnabled(enabled)
            loginError = nil
        } catch {
            loginError = "Cannot change the login item: \(error.localizedDescription)"
        }
        refreshLoginItem()
    }

    /// Reads the login item state from macOS into the view's state.
    private func refreshLoginItem() {
        // "Requires approval" counts as on for the toggle: the user asked for
        // it, and the note underneath explains what's left to do.
        needsApproval = LoginItem.needsApproval
        launchAtLogin = LoginItem.isEnabled || needsApproval
    }
}
