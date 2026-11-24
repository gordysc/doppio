import AppKit
import SwiftUI

/// Handles app lifecycle events that SwiftUI's `App` doesn't cover well, and owns the main window.
///
/// SwiftUI apps can still have an AppKit `NSApplicationDelegate`, attached
/// with `@NSApplicationDelegateAdaptor` in `DoppioApp`. We need it for:
/// - stopping `caffeinate` when the app quits,
/// - reopening the window when the app is launched again from Finder or Spotlight,
/// - making the window ourselves, so both the popover and the delegate can open it.
///
/// It subclasses `NSObject` because AppKit's delegate protocols are Objective-C
/// protocols, and only `NSObject` subclasses can adopt them.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The one model shared by every part of the app.
    let model = AppModel()

    /// The main window, created the first time it's shown and then reused.
    ///
    /// Optional because it doesn't exist until first opened. Reusing one
    /// window means "open" never stacks up duplicates.
    private var window: NSWindow?

    /// Applies saved settings once the app has launched.
    ///
    /// - Parameter notification: The launch notification (unused).
    func applicationDidFinishLaunching(_ notification: Notification) {
        model.applyActivationPolicy(activate: false)

        if model.prefs.activateOnLaunch {
            model.start()
        }

        // Show the window on the very first launch, so a new user sees
        // something, and whenever the menu bar icon is off, since there'd be
        // nothing else on screen.
        if !model.prefs.hasLaunchedBefore || !model.prefs.showMenuBarIcon {
            showMainWindow()
            model.prefs.hasLaunchedBefore = true
        }
    }

    /// Called when the user opens the app again while it's already running,
    /// e.g. by double-clicking it in Applications or clicking its Dock icon.
    ///
    /// - Parameters:
    ///   - sender: The application.
    ///   - flag: Whether any windows are visible.
    /// - Returns: `false`, meaning we've handled the reopen ourselves.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    /// Keeps running after the window closes. The menu bar icon remains.
    ///
    /// - Parameter sender: The application.
    /// - Returns: `false`, so closing the window doesn't quit the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Stops `caffeinate` so the Mac can sleep again once Doppio quits.
    ///
    /// `-w <our pid>` would also make `caffeinate` exit shortly after, but
    /// stopping it here releases the assertions straight away.
    ///
    /// - Parameter notification: The termination notification (unused).
    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    /// Shows the main window, creating it on first use, and brings it to the front.
    func showMainWindow() {
        // `if let` reuses the existing window if there is one.
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        // `NSHostingController` is the bridge from SwiftUI to AppKit: it wraps
        // a SwiftUI view in an AppKit view controller a window can show.
        let controller = NSHostingController(rootView: MainWindowView(model: model))
        // Resize the window whenever the SwiftUI content's ideal size changes,
        // e.g. when a different duration tab shows more or fewer controls.
        controller.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: controller)
        window.title = "Doppio"
        window.styleMask = [.titled, .closable, .miniaturizable]
        // AppKit's default would free the window on close, leaving our
        // reference dangling. Keep it alive so it can be shown again.
        window.isReleasedWhenClosed = false
        window.center()
        // Remember the position between launches under this name.
        window.setFrameAutosaveName("DoppioMainWindow")

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
