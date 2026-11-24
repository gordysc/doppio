import Foundation

/// Formats durations for display.
///
/// An enum with no cases can't be instantiated. That makes it the idiomatic
/// Swift "namespace" for related static functions, where another language
/// might use a static class.
public enum DurationText {
    /// Formats a countdown clock-style, such as `42:07` or `1:02:03`.
    ///
    /// - Parameter interval: Seconds remaining. Negative values show as `0:00`.
    /// - Returns: `m:ss` below an hour, `h:mm:ss` otherwise.
    public static func countdown(_ interval: TimeInterval) -> String {
        // Round up so the clock reads 0:00 only when time is fully up.
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formats a whole number of minutes compactly, such as `15m`, `2h`, or `1h 30m`.
    ///
    /// - Parameter minutes: The duration in minutes.
    /// - Returns: The compact label.
    public static func short(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        // Switching on a tuple matches both values at once; `_` matches anything.
        switch (hours, remainder) {
        case (0, _): return "\(remainder)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(remainder)m"
        }
    }
}
