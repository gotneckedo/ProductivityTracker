import Foundation

enum TimerMode: String, Codable, CaseIterable, Hashable {
    /// One fixed focus block (the "custom countdown").
    case countdown
    /// Open-ended focus; the user finishes when ready.
    case countUp
    /// Alternating focus and break blocks for `cycleCount` focus blocks.
    case pomodoro

    var displayName: String {
        switch self {
        case .countdown: return "Countdown"
        case .countUp: return "Count up"
        case .pomodoro: return "Pomodoro"
        }
    }
}

enum FocusPhaseKind: String, Codable, Hashable {
    case focus
    case shortBreak
    case longBreak

    var isBreak: Bool { self != .focus }

    var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long break"
        }
    }
}

/// One block inside a session. A `nil` duration means open-ended (count-up).
struct FocusPhase: Codable, Hashable {
    var kind: FocusPhaseKind
    var duration: TimeInterval?
}

/// The timer rules a session runs with. A snapshot is copied into every
/// `FocusSession`, so editing defaults never rewrites history.
struct TimerConfiguration: Codable, Hashable {
    var mode: TimerMode
    var focusDuration: TimeInterval
    var breakDuration: TimeInterval
    var longBreakDuration: TimeInterval
    /// A long break replaces the short break after every N focus blocks. 0 disables long breaks.
    var longBreakInterval: Int
    /// Intended number of focus blocks (Pomodoro only).
    var cycleCount: Int
    var autoStartBreaks: Bool
    var autoStartFocus: Bool
    /// Reserved for V2 routines / wake-up hand-off. Always nil in V1.
    var routineID: UUID?

    /// Count-up sessions shorter than this are recorded as abandoned and never
    /// grant progression. Documented in README ("Completion rules").
    static let minimumCountUpCompletion: TimeInterval = 5 * 60

    static let focusRange: ClosedRange<TimeInterval> = (5 * 60)...(180 * 60)
    static let breakRange: ClosedRange<TimeInterval> = (1 * 60)...(60 * 60)
    static let cycleRange: ClosedRange<Int> = 1...8

    static let standard = TimerConfiguration(
        mode: .countdown,
        focusDuration: 25 * 60,
        breakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        longBreakInterval: 4,
        cycleCount: 4,
        autoStartBreaks: true,
        autoStartFocus: false,
        routineID: nil
    )

    /// The ordered phase plan for this configuration.
    var phases: [FocusPhase] {
        switch mode {
        case .countdown:
            return [FocusPhase(kind: .focus, duration: focusDuration)]
        case .countUp:
            return [FocusPhase(kind: .focus, duration: nil)]
        case .pomodoro:
            var result: [FocusPhase] = []
            let cycles = max(1, cycleCount)
            for block in 1...cycles {
                result.append(FocusPhase(kind: .focus, duration: focusDuration))
                guard block < cycles else { break }
                if longBreakInterval > 0, block % longBreakInterval == 0 {
                    result.append(FocusPhase(kind: .longBreak, duration: longBreakDuration))
                } else {
                    result.append(FocusPhase(kind: .shortBreak, duration: breakDuration))
                }
            }
            return result
        }
    }

    var focusBlockCount: Int {
        phases.filter { $0.kind == .focus }.count
    }

    /// Planned focus time, or nil for open-ended sessions.
    var plannedFocusDuration: TimeInterval? {
        mode == .countUp ? nil : focusDuration * Double(focusBlockCount)
    }

    /// Break time offered on the session-complete screen.
    var suggestedBreakDuration: TimeInterval { breakDuration }

    /// Returns a copy with every value clamped into its supported range.
    func validated() -> TimerConfiguration {
        var copy = self
        copy.focusDuration = min(max(focusDuration, Self.focusRange.lowerBound), Self.focusRange.upperBound)
        copy.breakDuration = min(max(breakDuration, Self.breakRange.lowerBound), Self.breakRange.upperBound)
        copy.longBreakDuration = min(max(longBreakDuration, Self.breakRange.lowerBound), Self.breakRange.upperBound)
        copy.cycleCount = min(max(cycleCount, Self.cycleRange.lowerBound), Self.cycleRange.upperBound)
        copy.longBreakInterval = max(0, longBreakInterval)
        return copy
    }
}
