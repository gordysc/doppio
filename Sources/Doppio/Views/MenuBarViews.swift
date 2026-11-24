import AppKit
import DoppioCore
import SwiftUI

/// What the menu bar shows: a cup icon, plus the countdown when enabled.
struct MenuBarLabel: View {
    /// The shared model.
    let model: AppModel

    /// The icon, and the remaining time if there is a deadline.
    var body: some View {
        let isActive = model.session.isActive
        // The menu bar flattens a label into an icon plus a title, so an
        // `HStack` of one `Image` and one `Text` shows as "icon  42:07".
        HStack(spacing: 4) {
            Image(systemName: isActive ? "cup.and.heat.waves.fill" : "cup.and.saucer")
            // Combining conditions with commas in `if`: each must hold, and
            // `let remaining` unwraps the optional for use inside.
            if isActive, model.prefs.showCountdownInMenuBar, let remaining = model.session.remaining {
                Text(DurationText.countdown(remaining)).monospacedDigit()
            }
        }
        .accessibilityLabel(isActive ? "Doppio: the Mac stays awake" : "Doppio: normal sleep")
    }
}

/// The popover that opens when you click the menu bar icon.
struct MenuBarContent: View {
    /// The shared model.
    let model: AppModel

    /// Opens the full Doppio window. Passed in by the app because only the
    /// app delegate owns that window.
    let openWindow: () -> Void

    /// The control panel with window and quit buttons under it.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ControlPanel(model: model)
            Divider()
            HStack {
                Button("Settings…", action: openWindow)
                    .keyboardShortcut(",")
                Spacer()
                Button("Quit Doppio") {
                    // `terminate` gives the delegate a chance to clean up
                    // (it stops `caffeinate` in `applicationWillTerminate`).
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
