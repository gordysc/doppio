import Foundation
import Testing
// `@testable` also exposes `internal` declarations to the tests, not just `public` ones.
@testable import DoppioCore

// These tests use Swift Testing (`import Testing`), Apple's newer framework.
// `@Suite` groups tests, `@Test` marks one, and `#expect` checks a condition
// and reports the actual values when it fails.

/// Checks how a `CaffeinateCommand` turns into command-line arguments.
@Suite struct CaffeinateCommandTests {
    /// Flags come out in a fixed order however the set was built.
    @Test func flagsFollowCanonicalOrder() {
        let command = CaffeinateCommand(assertions: [.user, .display, .idle])
        #expect(command.arguments == ["-diu"])
    }

    /// An empty set adds no flag argument (a bare `-` would be an error).
    @Test func noAssertionsMeansNoFlagArgument() {
        #expect(CaffeinateCommand(assertions: []).arguments.isEmpty)
    }

    /// `-t` and `-w` come after the flags, each followed by its value.
    @Test func timeoutAndWaitPIDAreAppended() {
        let command = CaffeinateCommand(assertions: [.display], timeout: 900, waitPID: 42)
        #expect(command.arguments == ["-d", "-t", "900", "-w", "42"])
        #expect(command.commandLine == "caffeinate -d -t 900 -w 42")
    }

    /// A fractional time to the deadline rounds up, and the fallback pid is used.
    @Test func timeoutRoundsUpFromDeadline() {
        let now = Date(timeIntervalSince1970: 1_000)
        let command = CaffeinateCommand(
            assertions: [.idle], limit: .duration(60), deadline: now.addingTimeInterval(59.2),
            now: now, fallbackPID: 7
        )
        #expect(command.timeout == 60)
        #expect(command.waitPID == 7)
    }

    /// A deadline already in the past still gives `-t 1`, never zero or negative.
    @Test func pastDeadlineStillGivesPositiveTimeout() {
        let now = Date(timeIntervalSince1970: 1_000)
        let command = CaffeinateCommand(
            assertions: [.idle], limit: .duration(1), deadline: now.addingTimeInterval(-5),
            now: now, fallbackPID: nil
        )
        #expect(command.timeout == 1)
    }

    /// A limit that watches a process waits on that pid, not the fallback.
    @Test func watchedProcessOverridesFallbackPID() {
        let command = CaffeinateCommand(
            assertions: [.idle], limit: .whileProcessRuns(pid: 99), deadline: nil,
            now: .now, fallbackPID: 7
        )
        #expect(command.arguments == ["-i", "-w", "99"])
    }
}

/// Checks how each `SessionLimit` works out its deadline.
@Suite struct SessionLimitTests {
    /// A fixed UTC calendar, so results don't depend on the machine's time zone.
    ///
    /// The `= { ... }()` pattern runs a closure once to build the value, which
    /// lets us configure it in several statements.
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // `!` force-unwraps: "UTC" always exists, so a crash here would be a real bug.
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Builds a date in March 2026 in the test calendar.
    ///
    /// - Parameters:
    ///   - hour: The hour, 0–23.
    ///   - minute: The minute, 0–59.
    ///   - day: The day of the month.
    /// - Returns: The matching date.
    func date(_ hour: Int, _ minute: Int, day: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
    }

    /// A time later today resolves to today.
    @Test func untilTimeLaterToday() {
        let deadline = SessionLimit.untilTime(hour: 17, minute: 30).deadline(from: date(9, 0), calendar: calendar)
        #expect(deadline == date(17, 30))
    }

    /// A time already past today resolves to tomorrow.
    @Test func untilTimeAlreadyPassedRollsToTomorrow() {
        let deadline = SessionLimit.untilTime(hour: 8, minute: 0).deadline(from: date(9, 0), calendar: calendar)
        #expect(deadline == date(8, 0, day: 11))
    }

    /// Indefinite and process-bound sessions have no fixed end.
    @Test func openEndedLimitsHaveNoDeadline() {
        #expect(SessionLimit.indefinite.deadline(from: .now) == nil)
        #expect(SessionLimit.whileProcessRuns(pid: 1).deadline(from: .now) == nil)
    }
}

/// Checks the human-readable duration formats.
@Suite struct DurationTextTests {
    /// Clock-style countdowns, including rounding up partial seconds.
    ///
    /// `arguments:` runs the test once per tuple, each reported as its own case.
    @Test(arguments: [(0.0, "0:00"), (59.1, "1:00"), (2527, "42:07"), (3723, "1:02:03")])
    func countdown(seconds: TimeInterval, expected: String) {
        #expect(DurationText.countdown(seconds) == expected)
    }

    /// Compact minute labels.
    @Test(arguments: [(15, "15m"), (60, "1h"), (90, "1h 30m"), (480, "8h")])
    func short(minutes: Int, expected: String) {
        #expect(DurationText.short(minutes: minutes) == expected)
    }
}
