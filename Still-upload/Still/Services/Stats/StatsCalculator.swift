import Foundation

struct DayFocus: Equatable, Identifiable {
    var day: Date
    var focusDuration: TimeInterval
    var sessionCount: Int

    var id: Date { day }
}

struct ActivityUsageCount: Equatable, Identifiable {
    var activityID: BreakActivityID
    var completedCount: Int
    var openedCount: Int

    var id: BreakActivityID { activityID }
}

/// "Is this helping me?" All values derive from persisted sessions and usage.
struct FocusStats: Equatable {
    var completedSessions: Int
    var totalFocus: TimeInterval
    var todayFocus: TimeInterval
    /// Rolling seven days including today.
    var weekFocus: TimeInterval
    var averageSessionDuration: TimeInterval
    var currentStreak: Int
    var longestStreak: Int
    /// Oldest first, exactly seven entries ending today.
    var lastSevenDays: [DayFocus]
    /// Sorted by completions, then opens.
    var activityUsage: [ActivityUsageCount]
    var activitiesCompleted: Int

    static let empty = FocusStats(
        completedSessions: 0, totalFocus: 0, todayFocus: 0, weekFocus: 0,
        averageSessionDuration: 0, currentStreak: 0, longestStreak: 0,
        lastSevenDays: [], activityUsage: [], activitiesCompleted: 0
    )

    var hasHistory: Bool { completedSessions > 0 }
}

/// Focus-day streaks.
///
/// Rule: a focus day is a calendar day (in the user's current calendar and
/// time zone) with at least one *completed* session, attributed to the day the
/// session ended. The current streak counts consecutive focus days ending
/// today, or ending yesterday if nothing is completed yet today. Missing a
/// whole day resets the current streak to zero. Abandoned sessions never count.
struct StreakCalculator {
    var calendar: Calendar

    func focusDays(from sessions: [FocusSession]) -> Set<Date> {
        Set(sessions.compactMap { session in
            guard session.state == .completed, let ended = session.endedAt else { return nil }
            return calendar.startOfDay(for: ended)
        })
    }

    func currentStreak(days: Set<Date>, today: Date) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        var cursor: Date
        if days.contains(todayStart) {
            cursor = todayStart
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart), days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func longestStreak(days: Set<Date>) -> Int {
        let sorted = days.sorted()
        var longest = 0
        var run = 0
        var previous: Date?
        for day in sorted {
            if let prev = previous,
               let expected = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(expected, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = day
        }
        return longest
    }
}

struct StatsCalculator {
    var calendar: Calendar

    func stats(sessions: [FocusSession], usages: [ActivityUsage], now: Date) -> FocusStats {
        let completed = sessions.filter { $0.state == .completed && $0.endedAt != nil }
        let streaks = StreakCalculator(calendar: calendar)
        let days = streaks.focusDays(from: completed)
        let todayStart = calendar.startOfDay(for: now)

        var lastSeven: [DayFocus] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let onDay = completed.filter { calendar.isDate($0.endedAt!, inSameDayAs: day) }
            lastSeven.append(DayFocus(
                day: day,
                focusDuration: onDay.reduce(0) { $0 + $1.completedFocusDuration },
                sessionCount: onDay.count
            ))
        }

        let total = completed.reduce(0) { $0 + $1.completedFocusDuration }

        var usageCounts: [BreakActivityID: ActivityUsageCount] = [:]
        for usage in usages {
            var entry = usageCounts[usage.activityID] ?? ActivityUsageCount(activityID: usage.activityID, completedCount: 0, openedCount: 0)
            entry.openedCount += 1
            if usage.outcome == .completed { entry.completedCount += 1 }
            usageCounts[usage.activityID] = entry
        }
        let usageList = usageCounts.values.sorted {
            ($0.completedCount, $0.openedCount, $1.activityID.rawValue) > ($1.completedCount, $1.openedCount, $0.activityID.rawValue)
        }

        return FocusStats(
            completedSessions: completed.count,
            totalFocus: total,
            todayFocus: lastSeven.last?.focusDuration ?? 0,
            weekFocus: lastSeven.reduce(0) { $0 + $1.focusDuration },
            averageSessionDuration: completed.isEmpty ? 0 : total / Double(completed.count),
            currentStreak: streaks.currentStreak(days: days, today: now),
            longestStreak: streaks.longestStreak(days: days),
            lastSevenDays: lastSeven,
            activityUsage: usageList,
            activitiesCompleted: usages.filter { $0.outcome == .completed }.count
        )
    }

    /// Gentle, non-judgmental streak copy.
    static func streakLine(current: Int) -> String {
        switch current {
        case 0: return "A streak starts with any one session."
        case 1: return "You've focused one day in a row."
        default: return "You've focused \(current) days in a row."
        }
    }
}
