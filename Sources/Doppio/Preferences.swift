import Foundation
import Observation
import DoppioCore

/// The kind of session limit the user picked in the Duration control.
///
/// This is separate from `SessionLimit` because the UI also remembers the
/// settings of kinds that aren't selected (e.g. the 90-minute duration stays
/// saved while "Until" is picked). `Preferences` combines the kind and its
/// settings into a `SessionLimit` when a session starts.
enum LimitKind: String, CaseIterable, Identifiable {
    /// Stay awake until turned off.
    case indefinite
    /// Stay awake for a number of minutes.
    case duration
    /// Stay awake until a time of day.
    case untilTime
    /// Stay awake while a chosen app is running.
    case whileAppRuns

    /// Identity for SwiftUI's `ForEach`.
    var id: String { rawValue }

    /// The label shown in the segmented control.
    var title: String {
        switch self {
        case .indefinite: "Forever"
        case .duration: "For"
        case .untilTime: "Until"
        case .whileAppRuns: "While App"
        }
    }
}

/// The user's settings, saved to `UserDefaults` so they survive relaunches.
///
/// `@Observable` (from the Observation framework) makes SwiftUI views that
/// *read* a property here re-render when that property changes. It tracks
/// reads per property, so a view showing only `showDockIcon` won't re-render
/// when `durationMinutes` changes.
///
/// `@MainActor` pins every use of this class to the main thread. UI state must
/// only be touched there, and the annotation makes the compiler enforce it.
///
/// It's a `class`, not a `struct`, because the menu bar popover, the window,
/// and the app delegate must all share *one* copy and see each other's changes.
@MainActor
@Observable
final class Preferences {
    /// The `UserDefaults` keys, kept together so a typo can't make a read and a write disagree.
    private enum Key {
        /// Saved assertion raw values.
        static let assertions = "assertions"
        /// Saved `LimitKind` raw value.
        static let limitKind = "limitKind"
        /// Saved duration in minutes.
        static let durationMinutes = "durationMinutes"
        /// Saved "until" time as minutes after midnight.
        static let untilMinuteOfDay = "untilMinuteOfDay"
        /// Whether to start a session at launch.
        static let activateOnLaunch = "activateOnLaunch"
        /// Whether the menu bar icon is visible.
        static let showMenuBarIcon = "showMenuBarIcon"
        /// Whether the remaining time shows next to the menu bar icon.
        static let showCountdownInMenuBar = "showCountdownInMenuBar"
        /// Whether the app has a Dock icon.
        static let showDockIcon = "showDockIcon"
        /// Whether the app has launched before, used to show the window on first run.
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    /// The store the values are saved to.
    ///
    /// `@ObservationIgnored` excludes this from change tracking: it never
    /// changes, and views never need to re-render because of it.
    @ObservationIgnored private let defaults: UserDefaults

    // Each property below saves itself in `didSet`, an observer that runs after
    // every assignment. (It does *not* run for the first assignment in `init`.)

    /// Which assertions a session holds.
    var assertions: Set<Assertion> {
        didSet { defaults.set(assertions.map(\.rawValue).sorted(), forKey: Key.assertions) }
    }

    /// Which kind of limit the Duration control has selected.
    var limitKind: LimitKind {
        didSet { defaults.set(limitKind.rawValue, forKey: Key.limitKind) }
    }

    /// Minutes a "For" session lasts.
    var durationMinutes: Int {
        didSet { defaults.set(durationMinutes, forKey: Key.durationMinutes) }
    }

    /// The "Until" time, as minutes after midnight (e.g. 17:30 is 1050).
    var untilMinuteOfDay: Int {
        didSet { defaults.set(untilMinuteOfDay, forKey: Key.untilMinuteOfDay) }
    }

    /// Whether to start a session as soon as the app launches.
    var activateOnLaunch: Bool {
        didSet { defaults.set(activateOnLaunch, forKey: Key.activateOnLaunch) }
    }

    /// Whether the menu bar icon is visible.
    var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon) }
    }

    /// Whether the remaining time shows next to the menu bar icon.
    var showCountdownInMenuBar: Bool {
        didSet { defaults.set(showCountdownInMenuBar, forKey: Key.showCountdownInMenuBar) }
    }

    /// Whether the app shows an icon in the Dock.
    var showDockIcon: Bool {
        didSet { defaults.set(showDockIcon, forKey: Key.showDockIcon) }
    }

    /// Whether the app has launched before.
    var hasLaunchedBefore: Bool {
        didSet { defaults.set(hasLaunchedBefore, forKey: Key.hasLaunchedBefore) }
    }

    /// Loads saved settings, using defaults for anything never saved.
    ///
    /// - Parameter defaults: The store to read and write. Defaults to the app's standard store.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // `stringArray(forKey:)` returns an optional: `nil` if nothing was ever saved.
        // `.map { ... }` runs only on a saved array; `?? [...]` supplies the
        // default otherwise. `compactMap` drops any string that no longer
        // matches a case (`Assertion(rawValue:)` returns `nil` for those).
        assertions = defaults.stringArray(forKey: Key.assertions)
            .map { Set($0.compactMap(Assertion.init(rawValue:))) } ?? [.display, .idle]

        // `flatMap` here is like `map`, but the closure itself returns an
        // optional (`LimitKind(rawValue:)` can fail). Using `map` would give
        // a nested `LimitKind??`; `flatMap` flattens it to `LimitKind?`.
        limitKind = defaults.string(forKey: Key.limitKind).flatMap(LimitKind.init(rawValue:)) ?? .indefinite

        // `integer(forKey:)` returns 0 for missing keys, which is indistinguishable
        // from a saved 0. `object(forKey:) as? Int` returns `nil` when missing,
        // so `??` can tell "never saved" apart and apply the real default.
        durationMinutes = defaults.object(forKey: Key.durationMinutes) as? Int ?? 60
        untilMinuteOfDay = defaults.object(forKey: Key.untilMinuteOfDay) as? Int ?? 17 * 60
        activateOnLaunch = defaults.object(forKey: Key.activateOnLaunch) as? Bool ?? false
        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        showCountdownInMenuBar = defaults.object(forKey: Key.showCountdownInMenuBar) as? Bool ?? true
        showDockIcon = defaults.object(forKey: Key.showDockIcon) as? Bool ?? false
        hasLaunchedBefore = defaults.bool(forKey: Key.hasLaunchedBefore)
    }

    /// The hour (0–23) of the "Until" time.
    var untilHour: Int { untilMinuteOfDay / 60 }

    /// The minute (0–59) of the "Until" time.
    var untilMinute: Int { untilMinuteOfDay % 60 }

    /// Builds the session limit the current settings describe.
    ///
    /// - Parameter targetPID: The pid of the app chosen under "While App", if any.
    /// - Returns: The limit, or `nil` when "While App" is selected but no app is chosen.
    func sessionLimit(targetPID: Int32?) -> SessionLimit? {
        switch limitKind {
        case .indefinite:
            return .indefinite
        case .duration:
            return .duration(TimeInterval(durationMinutes * 60))
        case .untilTime:
            return .untilTime(hour: untilHour, minute: untilMinute)
        case .whileAppRuns:
            // `guard let` is Swift's early-exit unwrap: if `targetPID` is nil,
            // leave now; below the guard, `targetPID` is a plain `Int32`.
            // It reads better than wrapping the happy path in `if let { }`.
            guard let targetPID else { return nil }
            return .whileProcessRuns(pid: targetPID)
        }
    }
}
