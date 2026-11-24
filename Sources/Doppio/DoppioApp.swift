import SwiftUI

/// The app's entry point.
///
/// `@main` marks where the program starts. For a SwiftUI `App`, Swift
/// generates the `main()` that creates this struct and runs the app.
@main
struct DoppioApp: App {
    /// Connects our AppKit delegate to SwiftUI.
    ///
    /// SwiftUI creates one `AppDelegate`, hands it to `NSApplication` as the
    /// delegate, and keeps it for the app's lifetime. This property wrapper is
    /// the documented way to get lifecycle callbacks in a SwiftUI app.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// The app's scenes. Here that's just the menu bar item; the delegate
    /// manages the main window itself.
    var body: some Scene {
        // A local name for the shared model, to keep the lines below short.
        let model = appDelegate.model

        // `MenuBarExtra` puts an item in the menu bar. The `.window` style
        // opens a popover-like panel with our SwiftUI content, rather than a
        // plain menu, so checkboxes and pickers work as in a window.
        //
        // `isInserted` controls whether the item is shown. Binding it to the
        // preference means unticking "Show in menu bar" removes it. It also
        // works the other way: if the user Command-drags the icon off the menu
        // bar, macOS writes `false`, and we turn the Dock icon on.
        MenuBarExtra(isInserted: Binding(
            get: { model.prefs.showMenuBarIcon },
            set: { model.setShowMenuBarIcon($0) }
        )) {
            // Trailing closures: the first `{ }` is the panel content, and
            // `label:` is what sits in the menu bar itself.
            MenuBarContent(model: model, openWindow: { appDelegate.showMainWindow() })
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
