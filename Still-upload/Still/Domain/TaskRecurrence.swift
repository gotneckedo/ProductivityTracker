import Foundation

enum TaskDayPeriod: String, Codable, CaseIterable, Hashable, Identifiable {
    case anytime
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anytime: return "Anytime"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
}

enum TaskRepeatFrequency: String, Codable, CaseIterable, Hashable, Identifiable {
    case once
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

/// A compact recurrence rule owned by a task. Weekdays use Calendar weekday
/// values (1 = Sunday ... 7 = Saturday), keeping calculation locale-neutral.
struct TaskRepeatRule: Codable, Hashable {
    var frequency: TaskRepeatFrequency
    var interval: Int
    var weekdays: Set<Int>

    static let once = TaskRepeatRule(frequency: .once, interval: 1, weekdays: [])

    init(frequency: TaskRepeatFrequency, interval: Int = 1, weekdays: Set<Int> = []) {
        self.frequency = frequency
        self.interval = min(max(interval, 1), 99)
        self.weekdays = Set(weekdays.filter { 1...7 ~= $0 })
    }

    var isRepeating: Bool { frequency != .once }

    func normalized(anchor: Date, calendar: Calendar) -> TaskRepeatRule {
        var copy = self
        copy.interval = min(max(interval, 1), 99)
        copy.weekdays = Set(weekdays.filter { 1...7 ~= $0 })
        if copy.frequency == .weekly, copy.weekdays.isEmpty {
            copy.weekdays = [calendar.component(.weekday, from: anchor)]
        }
        if copy.frequency != .weekly { copy.weekdays = [] }
        return copy
    }

    func occurs(on day: Date, anchoredAt anchor: Date, calendar: Calendar) -> Bool {
        let target = calendar.startOfDay(for: day)
        let origin = calendar.startOfDay(for: anchor)
        guard target >= origin else { return false }
        let rule = normalized(anchor: anchor, calendar: calendar)

        switch rule.frequency {
        case .once:
            return calendar.isDate(target, inSameDayAs: origin)
        case .daily:
            let days = calendar.dateComponents([.day], from: origin, to: target).day ?? 0
            return days % rule.interval == 0
        case .weekly:
            guard rule.weekdays.contains(calendar.component(.weekday, from: target)),
                  let originWeek = calendar.dateInterval(of: .weekOfYear, for: origin)?.start,
                  let targetWeek = calendar.dateInterval(of: .weekOfYear, for: target)?.start else { return false }
            let weeks = calendar.dateComponents([.weekOfYear], from: originWeek, to: targetWeek).weekOfYear ?? 0
            return weeks >= 0 && weeks % rule.interval == 0
        case .monthly:
            let originParts = calendar.dateComponents([.year, .month, .day], from: origin)
            let targetParts = calendar.dateComponents([.year, .month, .day], from: target)
            guard let originYear = originParts.year, let originMonth = originParts.month, let originDay = originParts.day,
                  let targetYear = targetParts.year, let targetMonth = targetParts.month, let targetDay = targetParts.day else { return false }
            let months = (targetYear - originYear) * 12 + targetMonth - originMonth
            guard months >= 0, months % rule.interval == 0,
                  let daysInMonth = calendar.range(of: .day, in: .month, for: target)?.count else { return false }
            return targetDay == min(originDay, daysInMonth)
        }
    }

    /// Moves an anchored time onto a recurrence day without losing the original
    /// hour/minute. DST gaps fall back to the start of that day.
    func date(on day: Date, preservingTimeFrom anchor: Date, calendar: Calendar) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: anchor)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0,
                             second: time.second ?? 0, of: day)
            ?? calendar.startOfDay(for: day)
    }
}

extension TaskItem {
    var recurrenceAnchor: Date { scheduledAt ?? dueAt ?? createdAt }

    func occurs(on day: Date, calendar: Calendar) -> Bool {
        repeatRule.occurs(on: day, anchoredAt: recurrenceAnchor, calendar: calendar)
    }

    func isCompleted(on day: Date, calendar: Calendar) -> Bool {
        if repeatRule.isRepeating {
            return completedOccurrenceDays.contains { calendar.isDate($0, inSameDayAs: day) }
        }
        return completedAt != nil
    }
}
