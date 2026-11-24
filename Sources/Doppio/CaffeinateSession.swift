import Foundation
import Observation
import DoppioCore

/// Runs and tracks the `/usr/bin/caffeinate` child process.
///
/// Doppio doesn't call the power-management APIs itself. It starts the real
/// `caffeinate` tool, so what you configure in the GUI is exactly what the
/// shown command line would do in Terminal.
///
/// Two layers make sure the Mac is allowed to sleep again:
/// 1. `caffeinate` gets `-t <seconds>` when the session has a deadline.
/// 2. `caffeinate` gets `-w <our pid>` (or the watched app's pid), so even if
///    Doppio crashes, `caffeinate` notices and exits.
@MainActor
@Observable
final class CaffeinateSession {
    /// Whether a `caffeinate` process is currently running for us.
    ///
    /// `private(set)` means anyone can read it, but only this class can change it.
    private(set) var isActive = false

    /// When the current session ends, or `nil` if it has no fixed end.
    private(set) var deadline: Date?

    /// The command the running process was started with.
    private(set) var activeCommand: CaffeinateCommand?

    /// The limit the running session was started with.
    private(set) var activeLimit: SessionLimit?

    /// A message about the last unexpected exit, shown in the UI. Cleared on the next start.
    private(set) var lastError: String?

    /// The current time, refreshed every second while a deadline is running.
    ///
    /// Views compute the countdown from `deadline` and `now`. Because this is an
    /// observed property, assigning it each second re-renders exactly the views
    /// that show the countdown.
    private(set) var now = Date()

    /// The running process. Not observed: views care about `isActive`, not the `Process` object.
    @ObservationIgnored private var process: Process?

    /// The one-second timer driving `now`, alive only while a deadline is running.
    @ObservationIgnored private var ticker: Timer?

    /// Called on the main actor when a session ends by itself (timeout, watched
    /// app quit, or `caffeinate` killed), but not when `stop()` ends it.
    @ObservationIgnored var onUnexpectedEnd: (() -> Void)?

    /// Seconds left before the deadline, or `nil` if there's no deadline.
    var remaining: TimeInterval? {
        // `Optional.map`: no deadline gives `nil`, otherwise the seconds left (never below 0).
        deadline.map { max(0, $0.timeIntervalSince(now)) }
    }

    /// Starts a new session, replacing any running one.
    ///
    /// - Parameters:
    ///   - assertions: The assertions to hold.
    ///   - limit: How long the session lasts.
    func start(assertions: Set<Assertion>, limit: SessionLimit) {
        let startTime = Date()
        launch(assertions: assertions, limit: limit, deadline: limit.deadline(from: startTime))
    }

    /// Restarts the running session with new assertions, keeping its deadline.
    ///
    /// `caffeinate` can't change its flags while running, so we replace the
    /// process. Reusing the old deadline means toggling a checkbox doesn't
    /// reset a "1 hour" countdown back to a full hour.
    ///
    /// - Parameter assertions: The new set of assertions.
    func restart(assertions: Set<Assertion>) {
        guard isActive, let activeLimit else { return }
        launch(assertions: assertions, limit: activeLimit, deadline: deadline)
    }

    /// Ends the session and lets the Mac sleep normally again.
    func stop() {
        // Clear `process` *before* terminating it. The termination handler
        // compares the exiting pid with `process`, sees no match, and so
        // doesn't report this intentional stop as an unexpected end.
        let running = process
        process = nil
        running?.terminate()
        resetState()
    }

    /// Starts `caffeinate` with the given settings.
    ///
    /// - Parameters:
    ///   - assertions: The assertions to hold.
    ///   - limit: The session limit, remembered for `restart(assertions:)`.
    ///   - deadline: When to end, or `nil` for no fixed end.
    private func launch(assertions: Set<Assertion>, limit: SessionLimit, deadline: Date?) {
        stop()
        lastError = nil

        let command = CaffeinateCommand(
            assertions: assertions,
            limit: limit,
            deadline: deadline,
            now: Date(),
            fallbackPID: ProcessInfo.processInfo.processIdentifier
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: CaffeinateCommand.executablePath)
        process.arguments = command.arguments

        // `terminationHandler` is called on a background thread when the
        // process exits. Two things to handle:
        //
        // - `[weak self]`: the closure is stored on `process`, and `self`
        //   holds `process`. A strong capture would make a cycle
        //   (self -> process -> closure -> self) and neither would be freed.
        //   `weak` makes `self` an optional that becomes nil if this object goes away.
        // - Threads: this class is `@MainActor`, so we can't touch it from the
        //   background thread. `Task { @MainActor in ... }` schedules the work
        //   on the main actor. We copy out the pid and status first because
        //   they're plain integers, safe to send across threads.
        process.terminationHandler = { [weak self] finished in
            let pid = finished.processIdentifier
            let status = finished.terminationStatus
            Task { @MainActor in
                self?.processDidExit(pid: pid, status: status)
            }
        }

        // `do`/`try`/`catch` is Swift's error handling. `run()` is marked
        // `throws`; `try` marks the call that can fail, and on failure execution
        // jumps to `catch`, where the error is available as `error`.
        do {
            try process.run()
        } catch {
            lastError = "Cannot start caffeinate: \(error.localizedDescription)"
            return
        }

        self.process = process
        self.deadline = deadline
        self.activeCommand = command
        self.activeLimit = limit
        self.now = Date()
        isActive = true
        if deadline != nil {
            startTicker()
        }
    }

    /// Handles a `caffeinate` exit reported by the termination handler.
    ///
    /// - Parameters:
    ///   - pid: The pid of the process that exited.
    ///   - status: Its exit status (or the signal number, if it was killed).
    private func processDidExit(pid: Int32, status: Int32) {
        // Ignore exits of processes we've already replaced or stopped.
        guard pid == process?.processIdentifier else { return }
        process = nil

        // Exit status 0 is a normal end: the timeout passed or the watched app
        // quit. Anything else means it failed or something killed it.
        if status != 0 {
            lastError = "caffeinate stopped with an error (status \(status))."
        }
        resetState()
        onUnexpectedEnd?()
    }

    /// Clears all per-session state.
    private func resetState() {
        ticker?.invalidate()
        ticker = nil
        isActive = false
        deadline = nil
        activeCommand = nil
        activeLimit = nil
    }

    /// Starts the one-second timer that refreshes `now`.
    private func startTicker() {
        ticker?.invalidate()
        // A `Timer` closure must be `@Sendable`, so Swift won't assume it runs
        // on the main actor. It does, because we add it to the main run loop,
        // and `MainActor.assumeIsolated` tells the compiler so (and traps if
        // that's ever wrong). `[weak self]` stops the run loop, which keeps
        // the timer alive, from also keeping this object alive.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        // `.common` mode keeps the timer firing while a menu is open. In the
        // default mode, run-loop timers pause while the user is in a menu.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    /// Advances the clock, and stops the session if the deadline has passed.
    private func tick() {
        now = Date()
        // A backstop for `-t`. Its countdown can pause while the Mac sleeps,
        // but the deadline is wall-clock time, so we enforce it ourselves too.
        if let deadline, now >= deadline {
            stop()
            onUnexpectedEnd?()
        }
    }
}
