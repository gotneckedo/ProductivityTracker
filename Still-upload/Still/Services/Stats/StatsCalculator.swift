import Foundation

enum FocusStatsRange: String, CaseIterable, Hashable {
    case day
    case week
    case month
    case year

    var displayName: String { rawValue.capitalized }

    var summaryName: String {
        switch self {
        case .day: return "Today"
        case .week: return "Last 7 days"
        case .month: return "This month"
        case .year: return "This year"
        }
    }
}

struct DayFocus: Equatable, Identifiable {
    var day: Date
    var focusDuration: TimeInterval
    var sessionCount: Int
    /// Ready-to-render subject segments for a stacked chart. Sessions without a
    /// task/subject use nil rather than inventing presentation data.
    var subjectSegments: [SubjectFocusSegment] = []

    var id: Date { day }
}

struct SubjectFocusSegment: Equatable, Identifiable {
    var subject: Subject?
    var focusDuration: TimeInterval

    var id: String { subject?.id ?? "unassigned" }
}

struct FocusRangePoint: Equatable, Identifiable {
    var date: Date
    var focusDuration: TimeInterval
    var sessionCount: Int
    var subjectSegments: [SubjectFocusSegment] = []

    var id: Date { date }
}

enum UsualFocusComparison: Equatable {
    case lighter
    case aboutUsual
    case more
}

struct FocusRangeData: Equatable {
    var range: FocusStatsRange
    var start: Date
    /// Exclusive upper bound.
    var end: Date
    var focusDuration: TimeInterval
    var sessionCount: Int
    var points: [FocusRangePoint]
    /// The user's own average focused time on prior focus days. Today never
    /// changes the reference while it is still unfolding.
    var usualDailyFocus: TimeInterval?
    /// The usual reference converted to the unit used by each chart point.
    /// Day-based charts use a daily value; the year chart uses a typical month.
    var usualReferenceFocus: TimeInterval?
    var comparisonToUsual: UsualFocusComparison?
}

enum FocusCalendarDayKind: String, Equatable {
    case focused
    /// A neutral past or current day without a completed session.
    case quiet
    /// A neutral future day.
    case upcoming
}

struct FocusCalendarDay: Equatable, Identifiable {
    var date: Date
    var focusDuration: TimeInterval
    var sessionCount: Int
    var kind: FocusCalendarDayKind

    var id: Date { date }
}

struct FocusCalendarMonth: Equatable {
    var monthStart: Date
    var leadingWeekdayCount: Int
    var days: [FocusCalendarDay]

    static let empty = FocusCalendarMonth(
        monthStart: Date(timeIntervalSinceReferenceDate: 0),
        leadingWeekdayCount: 0,
        days: []
    )
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
    var ranges: [FocusStatsRange: FocusRangeData] = [:]
    var usualDailyFocus: TimeInterval? = nil
    var calendarMonth: FocusCalendarMonth = .empty

    static let empty = FocusStats(
        completedSessions: 0, totalFocus: 0, todayFocus: 0, weekFocus: 0,
        averageSessionDuration: 0, currentStreak: 0, longestStreak: 0,
        lastSevenDays: [], activityUsage: [], activitiesCompleted: 0
    )

    var hasHistory: Bool { completedSessions > 0 }

    func data(for range: FocusStatsRange) -> FocusRangeData? {
        ranges[range]
    }
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

    func stats(sessions: [FocusSession], usages: [ActivityUsage], tasks: [TaskItem] = [], now: Date) -> FocusStats {
        let completed = sessions.filter { $0.state == .completed && $0.endedAt != nil }
        let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let streaks = StreakCalculator(calendar: calendar)
        let days = streaks.focusDays(from: completed)
        let usual = usualDailyFocus(completed: completed, now: now)
        let ranges = Dictionary(uniqueKeysWithValues: FocusStatsRange.allCases.map { range in
            (range, rangeData(range, completed: completed, tasksByID: tasksByID, usualDailyFocus: usual, now: now))
        })
        let lastSeven = ranges[.week]?.points.map {
            DayFocus(day: $0.date, focusDuration: $0.focusDuration, sessionCount: $0.sessionCount,
                     subjectSegments: $0.subjectSegments)
        } ?? []

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
            activitiesCompleted: usages.filter { $0.outcome == .completed }.count,
            ranges: ranges,
            usualDailyFocus: usual,
            calendarMonth: calendarMonth(completed: completed, now: now)
        )
    }

    func rangeData(
        _ range: FocusStatsRange,
        sessions: [FocusSession],
        now: Date
    ) -> FocusRangeData {
        let completed = sessions.filter { $0.state == .completed && $0.endedAt != nil }
        return rangeData(range, completed: completed, tasksByID: [:], usualDailyFocus: usualDailyFocus(completed: completed, now: now), now: now)
    }

    func calendarMonth(sessions: [FocusSession], now: Date) -> FocusCalendarMonth {
        calendarMonth(completed: sessions.filter { $0.state == .completed && $0.endedAt != nil }, now: now)
    }

    private func usualDailyFocus(completed: [FocusSession], now: Date) -> TimeInterval? {
        let today = calendar.startOfDay(for: now)
        var totals: [Date: TimeInterval] = [:]
        for session in completed {
            guard let endedAt = session.endedAt, endedAt < today else { continue }
            totals[calendar.startOfDay(for: endedAt), default: 0] += session.completedFocusDuration
        }
        guard !totals.isEmpty else { return nil }
        return totals.values.reduce(0, +) / Double(totals.count)
    }

    private func rangeData(
        _ range: FocusStatsRange,
        completed: [FocusSession],
        tasksByID: [UUID: TaskItem],
        usualDailyFocus: TimeInterval?,
        now: Date
    ) -> FocusRangeData {
        let interval = interval(for: range, now: now)
        let sessionsInRange = completed.filter { session in
            guard let end = session.endedAt else { return false }
            return end >= interval.start && end < interval.end
        }
        let points = points(for: range, interval: interval, completed: sessionsInRange, tasksByID: tasksByID)
        let total = sessionsInRange.reduce(0) { $0 + $1.completedFocusDuration }
        let elapsedDays = max(1, calendar.dateComponents(
            [.day],
            from: interval.start,
            to: min(interval.end, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? interval.end)
        ).day ?? 1)
        let averagePerElapsedDay = total / Double(elapsedDays)
        let comparison = usualDailyFocus.map { usual in
            Self.comparison(focus: averagePerElapsedDay, usual: usual)
        }
        let reference = usualDailyFocus.map { usual in
            if range == .year {
                let daysInYear = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
                return usual * Double(daysInYear) / 12
            }
            return usual
        }
        return FocusRangeData(
            range: range,
            start: interval.start,
            end: interval.end,
            focusDuration: total,
            sessionCount: sessionsInRange.count,
            points: points,
            usualDailyFocus: usualDailyFocus,
            usualReferenceFocus: reference,
            comparisonToUsual: comparison
        )
    }

    private func interval(for range: FocusStatsRange, now: Date) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        switch range {
        case .day:
            return DateInterval(start: today, end: calendar.date(byAdding: .day, value: 1, to: today)!)
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: today)!
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: today)!)
        case .month:
            return calendar.dateInterval(of: .month, for: now)!
        case .year:
            return calendar.dateInterval(of: .year, for: now)!
        }
    }

    private func points(
        for range: FocusStatsRange,
        interval: DateInterval,
        completed: [FocusSession],
        tasksByID: [UUID: TaskItem]
    ) -> [FocusRangePoint] {
        switch range {
        case .day:
            return [point(start: interval.start, end: interval.end, completed: completed, tasksByID: tasksByID)]
        case .week, .month:
            var result: [FocusRangePoint] = []
            var cursor = interval.start
            while cursor < interval.end {
                let end = calendar.date(byAdding: .day, value: 1, to: cursor)!
                result.append(point(start: cursor, end: end, completed: completed, tasksByID: tasksByID))
                cursor = end
            }
            return result
        case .year:
            var result: [FocusRangePoint] = []
            var cursor = interval.start
            while cursor < interval.end {
                let end = calendar.date(byAdding: .month, value: 1, to: cursor)!
                result.append(point(start: cursor, end: end, completed: completed, tasksByID: tasksByID))
                cursor = end
            }
            return result
        }
    }

    private func point(start: Date, end: Date, completed: [FocusSession], tasksByID: [UUID: TaskItem] = [:]) -> FocusRangePoint {
        let matches = completed.filter { session in
            guard let endedAt = session.endedAt else { return false }
            return endedAt >= start && endedAt < end
        }
        var segments: [Subject?: TimeInterval] = [:]
        for session in matches {
            let subject = session.taskID.flatMap { tasksByID[$0]?.subject }
            segments[subject, default: 0] += session.completedFocusDuration
        }
        return FocusRangePoint(
            date: start,
            focusDuration: matches.reduce(0) { $0 + $1.completedFocusDuration },
            sessionCount: matches.count,
            subjectSegments: segments.map { SubjectFocusSegment(subject: $0.key, focusDuration: $0.value) }
                .sorted { ($0.subject?.name ?? "") < ($1.subject?.name ?? "") }
        )
    }

    private func calendarMonth(completed: [FocusSession], now: Date) -> FocusCalendarMonth {
        let interval = calendar.dateInterval(of: .month, for: now)!
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result: [FocusCalendarDay] = []
        var cursor = interval.start
        while cursor < interval.end {
            let end = calendar.date(byAdding: .day, value: 1, to: cursor)!
            let point = point(start: cursor, end: end, completed: completed)
            let kind: FocusCalendarDayKind
            if point.focusDuration > 0 {
                kind = .focused
            } else if cursor > today {
                kind = .upcoming
            } else {
                kind = .quiet
            }
            result.append(FocusCalendarDay(
                date: cursor,
                focusDuration: point.focusDuration,
                sessionCount: point.sessionCount,
                kind: kind
            ))
            cursor = end
        }
        return FocusCalendarMonth(monthStart: interval.start, leadingWeekdayCount: leading, days: result)
    }

    static func comparison(focus: TimeInterval, usual: TimeInterval) -> UsualFocusComparison {
        guard usual > 0 else { return .aboutUsual }
        if focus > usual * 1.25 { return .more }
        if focus < usual * 0.75 { return .lighter }
        return .aboutUsual
    }

    /// Gentle, non-judgmental streak copy.
    static func streakLine(current: Int) -> String {
        switch current {
        case 0: return "A streak starts with any one session."
        case 1: return "You've focused one day in a row."
        default: return "You've focused \(current) days in a row."
        }
    }

    /// A numeric streak value is omitted rather than ever presenting "0 days".
    static func streakValue(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return "\(count) \(count == 1 ? "day" : "days")"
    }
}
