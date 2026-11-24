import Foundation

/// A fully specified `caffeinate` invocation: which assertions, for how long,
/// and which process to wait on.
///
/// This is a `struct`, the Swift default for plain data. Structs are *value
/// types*: assigning one to a new variable copies it, so code holding a
/// command never sees it change behind its back. A `class` (a reference type)
/// would share one instance between everyone holding it.
public struct CaffeinateCommand: Equatable, Sendable {
    /// Where macOS ships the `caffeinate` binary.
    public static let executablePath = "/usr/bin/caffeinate"

    /// The assertions to hold. A `Set` because order and duplicates don't matter;
    /// `arguments` sorts them into a fixed order.
    public var assertions: Set<Assertion>
    /// Seconds until `caffeinate` drops its assertions and exits (`-t`), or `nil` for no limit.
    public var timeout: Int?
    /// Pid that `caffeinate` watches; it exits when that process exits (`-w`).
    public var waitPID: Int32?

    /// Creates a command from raw values.
    ///
    /// - Parameters:
    ///   - assertions: The assertions to hold.
    ///   - timeout: Seconds before `caffeinate` exits, or `nil` for no limit.
    ///   - waitPID: A pid to wait on, or `nil` to not wait on any process.
    public init(assertions: Set<Assertion>, timeout: Int? = nil, waitPID: Int32? = nil) {
        self.assertions = assertions
        self.timeout = timeout
        self.waitPID = waitPID
    }

    /// Creates the command for a session that ends at `deadline`.
    ///
    /// - Parameters:
    ///   - assertions: The assertions to hold.
    ///   - limit: The session's limit. If it watches a process, that pid wins over `fallbackPID`.
    ///   - deadline: When the session ends, or `nil` for no fixed end.
    ///   - now: The current time, passed in so tests can control it.
    ///   - fallbackPID: The pid to wait on when `limit` doesn't name one. The app
    ///     passes its own pid, so if the app crashes, `caffeinate` exits too
    ///     instead of keeping the Mac awake forever.
    public init(
        assertions: Set<Assertion>,
        limit: SessionLimit,
        deadline: Date?,
        now: Date,
        fallbackPID: Int32?
    ) {
        // `Optional.map` runs the closure only when there's a value inside:
        // a `Date` becomes an `Int`, and `nil` stays `nil`. `$0` is the
        // closure's first argument (the unwrapped deadline).
        // Rounding up and clamping to 1 means we never pass `-t 0`, and a
        // deadline 59.2s away keeps the Mac awake for the full time.
        let timeout = deadline.map { max(1, Int($0.timeIntervalSince(now).rounded(.up))) }
        // `??` ("nil-coalescing") uses the left side if it's non-nil, else the right.
        self.init(assertions: assertions, timeout: timeout, waitPID: limit.watchedPID ?? fallbackPID)
    }

    /// The argument list passed to the `caffeinate` process, e.g. `["-di", "-t", "900"]`.
    public var arguments: [String] {
        var arguments: [String] = []
        // Walk `allCases`, not the set, so flags always come out in the same
        // order (`-di`, never `-id`). Sets have no defined iteration order.
        // `.map(\.flag)` uses a *key path*: shorthand for `{ $0.flag }`.
        let flags = Assertion.allCases.filter(assertions.contains).map(\.flag)
        if !flags.isEmpty {
            arguments.append("-" + String(flags))
        }
        // `if let` unwraps the optional: the body runs only when `timeout` holds
        // a value, and inside it `timeout` is a plain `Int`.
        if let timeout {
            arguments += ["-t", String(timeout)]
        }
        if let waitPID {
            arguments += ["-w", String(waitPID)]
        }
        return arguments
    }

    /// The command as you would type it in Terminal, e.g. `caffeinate -di -t 900`.
    public var commandLine: String {
        (["caffeinate"] + arguments).joined(separator: " ")
    }
}
