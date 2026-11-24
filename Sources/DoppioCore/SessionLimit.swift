import Foundation

/// How long a keep-awake session lasts.
///
/// Swift enums can carry *associated values*: each case can hold its own data
/// (a number of seconds, a time of day, a pid). That models "one of these
/// shapes" more safely than a struct full of optionals, because a value can
/// only ever be one case and the compiler makes every `switch` handle them all.
public enum SessionLimit: Equatable, Sendable {
    /// Lasts until the user turns it off.
    case indefinite
    /// Lasts for a fixed number of seconds.
    case duration(TimeInterval)
    /// Lasts until the next occurrence of a wall-clock time (24-hour `hour`).
    case untilTime(hour: Int, minute: Int)
    /// Lasts until the process with this pid exits.
    case whileProcessRuns(pid: Int32)

    /// Works out when a session started at `now` should end.
    ///
    /// - Parameters:
    ///   - now: The moment the session starts.
    ///   - calendar: The calendar used to find the next matching time of day.
    ///     Tests pass a fixed UTC calendar so results don't depend on the machine.
    /// - Returns: The end date, or `nil` when the session has no fixed end.
    public func deadline(from now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        // Two cases can share one arm when neither binds a value we need.
        case .indefinite, .whileProcessRuns:
            return nil
        // `let seconds` pulls the associated value out of the case.
        case .duration(let seconds):
            return now.addingTimeInterval(seconds)
        case .untilTime(let hour, let minute):
            // `nextDate(after:matching:)` finds the first moment *strictly after*
            // `now` with this hour and minute. If 08:00 has passed today, it
            // returns 08:00 tomorrow, which is what "until 8am" means.
            // `.nextTime` handles daylight-saving gaps by moving to the next
            // valid time instead of failing.
            return calendar.nextDate(
                after: now,
                matching: DateComponents(hour: hour, minute: minute, second: 0),
                matchingPolicy: .nextTime
            )
        }
    }

    /// The pid `caffeinate` should wait on, if this limit is tied to another process.
    public var watchedPID: Int32? {
        // `if case` tests a single enum case and binds its value in one step.
        // As an expression, this whole `if` produces the pid or `nil`.
        if case .whileProcessRuns(let pid) = self { pid } else { nil }
    }
}
