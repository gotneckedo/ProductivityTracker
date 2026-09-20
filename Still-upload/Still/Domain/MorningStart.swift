import Foundation

/// A gentle morning prompt that opens Still to today's tasks and a first
/// session. Delivered as a local notification today; see `WakeUpScheduling`
/// for the AlarmKit version.
struct MorningStartPlan: Codable, Hashable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday.
    var weekdays: Set<Int>
    var presetID: FocusPresetID

    static let standard = MorningStartPlan(isEnabled: false, hour: 8, minute: 0,
                                           weekdays: [2, 3, 4, 5, 6], presetID: .defaultPreset)

    /// Clamped to real clock values and real weekdays.
    func validated() -> MorningStartPlan {
        var copy = self
        copy.hour = min(max(hour, 0), 23)
        copy.minute = min(max(minute, 0), 59)
        copy.weekdays = weekdays.filter { (1...7).contains($0) }
        return copy
    }

    /// "Weekdays at 8:00 AM"
    var summary: String {
        let time = MorningStartPlan.timeText(hour: hour, minute: minute)
        let days: String
        switch weekdays {
        case [2, 3, 4, 5, 6]: days = "Weekdays"
        case [1, 7]: days = "Weekends"
        case Set(1...7): days = "Every day"
        default:
            let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            days = weekdays.sorted().compactMap { (1...7).contains($0) ? names[$0 - 1] : nil }.joined(separator: ", ")
        }
        return days.isEmpty ? "No days chosen" : "\(days) at \(time)"
    }

    static func timeText(hour: Int, minute: Int) -> String {
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let minutes = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(displayHour):\(minutes) \(hour < 12 ? "AM" : "PM")"
    }
}

enum MorningStartCopy {
    static let title = "Good morning"
    static let body = "Pick one thing for today. Still has a session ready when you are."
    static let identifierPrefix = "still.morning."
}

/// Schedules the repeating morning prompt.
protocol MorningStartScheduling: AnyObject {
    func scheduleMorningStart(_ plan: MorningStartPlan)
    func cancelMorningStart()
}

/// Records the plan for tests and previews.
final class RecordingMorningStartScheduler: MorningStartScheduling {
    private(set) var scheduledPlan: MorningStartPlan?

    func scheduleMorningStart(_ plan: MorningStartPlan) {
        scheduledPlan = plan.isEnabled && !plan.weekdays.isEmpty ? plan : nil
    }

    func cancelMorningStart() {
        scheduledPlan = nil
    }
}
