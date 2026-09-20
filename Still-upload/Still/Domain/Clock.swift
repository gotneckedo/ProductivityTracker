import Foundation

/// The single source of "now" for timer, streak, and suggestion logic.
/// Inject a `ManualClock` in tests and previews for deterministic results.
protocol Clock: AnyObject {
    var now: Date { get }
}

final class SystemClock: Clock {
    var now: Date { Date() }
}

/// A controllable clock. Tests advance it to simulate backgrounding,
/// process restarts, and multi-day streaks.
final class ManualClock: Clock {
    var now: Date

    init(_ now: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    func set(_ date: Date) {
        now = date
    }
}
