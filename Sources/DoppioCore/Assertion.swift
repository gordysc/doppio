/// A sleep assertion that `caffeinate` can hold. Each case maps to one command-line flag.
///
/// An *assertion* is macOS's term for "a process asked the power manager to not do X".
/// You can list the live ones with `pmset -g assertions`.
///
/// This is an `enum` with a `String` raw value, so every case has a stable
/// string (`"display"`, `"idle"`, …) we can save to `UserDefaults` and read back
/// with `Assertion(rawValue:)`.
///
/// Conformances, briefly:
/// - `CaseIterable` gives us `Assertion.allCases`, used to list them in the UI
///   and to emit flags in a fixed order.
/// - `Codable` lets the value be encoded/decoded (JSON, plists) if we ever need it.
/// - `Sendable` promises the value is safe to pass between threads. An enum
///   with no stored references is automatically safe; saying so lets Swift 6's
///   strict concurrency checking accept it everywhere.
/// - `Identifiable` lets SwiftUI's `ForEach` tell rows apart via `id`.
public enum Assertion: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Prevents the display from sleeping (`-d`).
    case display
    /// Prevents the system from idle sleeping (`-i`).
    case idle
    /// Prevents the disk from idle sleeping (`-m`).
    case disk
    /// Prevents system sleep entirely, but only while on AC power (`-s`).
    case system
    /// Declares the user active, which wakes the display (`-u`).
    case user

    /// A stable identity for SwiftUI lists; the raw string is already unique.
    public var id: String { rawValue }

    /// The `caffeinate` flag letter for this assertion.
    public var flag: Character {
        // Swift 5.9+ lets a `switch` be used as an expression, so each arm's
        // value is returned directly without writing `return`.
        switch self {
        case .display: "d"
        case .idle: "i"
        case .disk: "m"
        case .system: "s"
        case .user: "u"
        }
    }

    /// A short, human-readable name shown as the checkbox label.
    public var title: String {
        switch self {
        case .display: "Display"
        case .idle: "System idle sleep"
        case .disk: "Disk idle sleep"
        case .system: "System sleep (on AC power)"
        case .user: "Declare user active"
        }
    }

    /// One sentence explaining the effect, shown under the checkbox label.
    public var detail: String {
        switch self {
        case .display: "Keep the screen on."
        case .idle: "Keep the Mac on when it is idle."
        case .disk: "Do not let the disks stop when they are idle."
        case .system: "Prevent all system sleep when the Mac uses AC power."
        case .user: "Turn on the display as if you pushed a key. If you do not set a duration, this lasts 5 seconds."
        }
    }
}
