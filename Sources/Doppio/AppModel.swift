import AppKit
import Observation
import DoppioCore

/// A running app the user can pick under "While App".
///
/// A `struct`: it's a small snapshot of data, copied freely, with no identity
/// of its own beyond its pid.
struct RunningAppChoice: Identifiable, Hashable {
    /// The app's process id, used as the `-w` argument.
    let pid: Int32
    /// The app's display name.
    let name: String

    /// Identity for SwiftUI lists; pids are unique among running processes.
    var id: Int32 { pid }
}

/// The single source of truth the whole UI reads and drives.
///
/// Views never change `session` or `prefs` directly. They call methods here,
/// which keep the two in step. For example, changing an assertion while a
/// session runs must both save the preference *and* restart `caffeinate`.
@MainActor
@Observable
final class AppModel {
    /// The user's saved settings.
    let prefs = Preferences()

    /// The running `caffeinate` session.
    let session = CaffeinateSession()

    /// The app chosen under "While App". Not saved: pids change every launch.
    private(set) var targetApp: RunningAppChoice?

    /// Regular (Dock-visible) apps that are running now, refreshed on demand.
    private(set) var runningApps: [RunningAppChoice] = []

    /// Wires up the session's end callback.
    init() {
        // `[weak self]` avoids a retain cycle: `self` owns `session`, which
        // would own this closure, which would own `self` again.
        session.onUnexpectedEnd = { [weak self] in
            // `guard let self` unwraps the weak reference for the rest of the
            // closure, or returns if the model is already gone.
            guard let self else { return }
            // A "While App" session ends when its app quits. Forget that app
            // and refresh the list so a dead pid can't be picked again.
            if prefs.limitKind == .whileAppRuns {
                targetApp = nil
                refreshRunningApps()
            }
        }
    }

    // MARK: - Derived state

    /// The limit the current settings describe, or `nil` if they're incomplete.
    var currentLimit: SessionLimit? {
        // `?.` (optional chaining): if `targetApp` is nil the whole expression
        // is nil instead of crashing.
        prefs.sessionLimit(targetPID: targetApp?.pid)
    }

    /// Whether the current settings are complete enough to start a session.
    var canStart: Bool {
        !prefs.assertions.isEmpty && currentLimit != nil
    }

    /// Why a session can't start, for display, or `nil` when it can.
    var startBlocker: String? {
        if prefs.assertions.isEmpty { return "Select one or more items to keep awake." }
        if currentLimit == nil { return "Select an app." }
        return nil
    }

    /// The command to display: the running one, or what Start would run.
    var displayedCommand: CaffeinateCommand? {
        if let active = session.activeCommand { return active }
        guard let limit = currentLimit else { return nil }
        let now = Date()
        return CaffeinateCommand(
            assertions: prefs.assertions,
            limit: limit,
            deadline: limit.deadline(from: now),
            now: now,
            fallbackPID: ProcessInfo.processInfo.processIdentifier
        )
    }

    /// A one-line status summary such as "Awake · 42:07 left".
    var statusLine: String {
        guard session.isActive else {
            return session.lastError ?? "Normal sleep"
        }
        if let remaining = session.remaining {
            return "Awake · \(DurationText.countdown(remaining)) left"
        }
        if case .whileProcessRuns = session.activeLimit, let targetApp {
            return "Awake while \(targetApp.name) runs"
        }
        return "Awake until you turn it off"
    }

    // MARK: - Session control

    /// Starts a session with the current settings, if they're complete.
    func start() {
        guard canStart, let limit = currentLimit else { return }
        session.start(assertions: prefs.assertions, limit: limit)
    }

    /// Ends the running session.
    func stop() {
        session.stop()
    }

    /// Turns the session on or off.
    ///
    /// - Parameter active: `true` to start, `false` to stop.
    func setActive(_ active: Bool) {
        // Ternary works for expressions, but for calling one of two functions
        // a plain if/else reads more clearly.
        if active { start() } else { stop() }
    }

    // MARK: - Editing settings

    /// Adds or removes one assertion, and applies it to a running session.
    ///
    /// - Parameters:
    ///   - assertion: The assertion to change.
    ///   - enabled: Whether it should be held.
    func setAssertion(_ assertion: Assertion, enabled: Bool) {
        if enabled {
            prefs.assertions.insert(assertion)
        } else {
            prefs.assertions.remove(assertion)
        }
        guard session.isActive else { return }
        // Unchecking the last box while running means "nothing to hold",
        // so end the session instead of running a flagless `caffeinate`.
        if prefs.assertions.isEmpty {
            stop()
        } else {
            session.restart(assertions: prefs.assertions)
        }
    }

    /// Picks a limit kind, and restarts a running session to use it.
    ///
    /// - Parameter kind: The new kind.
    func setLimitKind(_ kind: LimitKind) {
        prefs.limitKind = kind
        if kind == .whileAppRuns { refreshRunningApps() }
        limitDidChange()
    }

    /// Sets the "For" duration, and restarts a running session to use it.
    ///
    /// - Parameter minutes: The new duration in minutes.
    func setDuration(minutes: Int) {
        prefs.durationMinutes = minutes
        limitDidChange()
    }

    /// Sets the "Until" time, and restarts a running session to use it.
    ///
    /// - Parameter date: Any date; only its hour and minute are used.
    func setUntilTime(_ date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        // `DateComponents` fields are optional because a components value may
        // not include every field. We asked for hour and minute, so `?? 0` is
        // just a safe fallback.
        prefs.untilMinuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        limitDidChange()
    }

    /// Picks the app to watch under "While App", and restarts a running session to use it.
    ///
    /// - Parameter app: The app, or `nil` to clear the choice.
    func setTargetApp(_ app: RunningAppChoice?) {
        targetApp = app
        limitDidChange()
    }

    /// Re-reads the list of running apps.
    func refreshRunningApps() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        runningApps = NSWorkspace.shared.runningApplications
            // `.regular` apps are the ones with a Dock icon. This filters out
            // background agents and helpers, which are rarely what you'd pick.
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            // `compactMap` transforms and drops nils in one pass: an app with
            // no name is skipped.
            .compactMap { app in
                guard let name = app.localizedName else { return nil }
                return RunningAppChoice(pid: app.processIdentifier, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // If the chosen app quit since the last refresh, drop it.
        if let targetApp, !runningApps.contains(targetApp) {
            self.targetApp = nil
        }
    }

    /// After a limit setting changes, restarts a running session to use it.
    private func limitDidChange() {
        guard session.isActive else { return }
        // If the settings are now incomplete (e.g. "While App" with no app
        // chosen), stop instead of leaving a session that doesn't match the UI.
        if canStart { start() } else { stop() }
    }

    // MARK: - Appearance

    /// Shows or hides the menu bar icon.
    ///
    /// Hiding it forces the Dock icon on, so the app always has *some* visible
    /// way back in.
    ///
    /// - Parameter visible: Whether the menu bar icon should show.
    func setShowMenuBarIcon(_ visible: Bool) {
        prefs.showMenuBarIcon = visible
        if !visible { setShowDockIcon(true) }
    }

    /// Shows or hides the Dock icon.
    ///
    /// - Parameter visible: Whether the Dock icon should show. Ignored when
    ///   `false` while the menu bar icon is hidden.
    func setShowDockIcon(_ visible: Bool) {
        prefs.showDockIcon = visible || !prefs.showMenuBarIcon
        applyActivationPolicy()
    }

    /// Applies the Dock icon preference to the running app.
    ///
    /// The Info.plist sets `LSUIElement` (no Dock icon) so the app launches
    /// hidden. Switching the *activation policy* at runtime adds or removes
    /// the Dock icon without a relaunch: `.regular` has a Dock icon and menu
    /// bar menus, `.accessory` has neither.
    ///
    /// - Parameter activate: Whether to bring the app to the front afterwards.
    ///   Changing policy can push the app to the background, so a toggle in the
    ///   window wants this. At launch it doesn't, or opening at login would
    ///   steal focus.
    func applyActivationPolicy(activate: Bool = true) {
        NSApp.setActivationPolicy(prefs.showDockIcon ? .regular : .accessory)
        if activate {
            NSApp.activate()
        }
    }
}
