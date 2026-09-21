import Foundation

/// Calm, relative wording for due dates. Past due is stated plainly, never red.
struct DueDateDescriber {
    var calendar: Calendar

    func describe(_ due: Date, now: Date) -> String {
        let days = dayDistance(from: now, to: due)
        switch days {
        case ..<(-1): return "Past due · \(days > -7 ? weekdayName(due) : shortDate(due))"
        case -1: return "Past due · yesterday"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        case 2...6: return "Due \(weekdayName(due))"
        default: return "Due \(shortDate(due))"
        }
    }

    func isOverdue(_ due: Date, now: Date) -> Bool {
        dayDistance(from: now, to: due) < 0
    }

    /// Whole calendar days from `now`'s day to `date`'s day.
    func dayDistance(from now: Date, to date: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    func weekdayName(_ date: Date) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let index = calendar.component(.weekday, from: date) - 1
        return names[max(0, min(names.count - 1, index))]
    }

    func shortDate(_ date: Date) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let month = calendar.component(.month, from: date) - 1
        return "\(months[max(0, min(11, month))]) \(calendar.component(.day, from: date))"
    }

    /// "9:30 AM" style, independent of locale so it reads the same in tests.
    func shortTime(_ date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        let minutes = minute < 10 ? "0\(minute)" : "\(minute)"
        return minute == 0 ? "\(displayHour) \(suffix)" : "\(displayHour):\(minutes) \(suffix)"
    }
}

/// One row on the day timeline.
struct TimelineItem: Hashable, Identifiable {
    enum Kind: Hashable {
        /// A task with a scheduled time.
        case scheduledTask(UUID)
        /// A task due today with no time; shown in the "Due today" group.
        case dueTask(UUID)
        /// A completed focus session.
        case focusSession(UUID)
        /// A read-only calendar event.
        case calendarEvent(String)
    }

    var id: String
    var kind: Kind
    var title: String
    var start: Date
    var end: Date?
    var isDone: Bool
    var subject: Subject?

    /// A visible capsule never collapses to zero height. Untimed values do not
    /// use this duration.
    var duration: TimeInterval { max(0, (end ?? start).timeIntervalSince(start)) }
}

struct TimelineUntimedGroup: Hashable, Identifiable {
    var period: TaskDayPeriod
    var items: [TimelineItem]

    var id: TaskDayPeriod { period }
}

struct DayTimeline: Hashable {
    var day: Date
    var untimedGroups: [TimelineUntimedGroup]
    var timed: [TimelineItem]

    /// Compatibility for existing callers while the UI moves to four groups.
    var dueToday: [TimelineItem] { untimedGroups.flatMap(\.items) }
}

/// Builds the day view: scheduled tasks, calendar events, and finished focus
/// sessions, in time order. Tasks due that day without a time come first.
struct DayTimelineBuilder {
    var calendar: Calendar

    func items(
        for day: Date,
        tasks: [TaskItem],
        sessions: [FocusSession],
        events: [ExternalCalendarEvent]
    ) -> DayTimeline {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return DayTimeline(day: start, untimedGroups: [], timed: [])
        }
        let inDay: (Date) -> Bool = { $0 >= start && $0 < end }

        var untimedByPeriod: [TaskDayPeriod: [TimelineItem]] = [:]

        var timed: [TimelineItem] = []
        for task in tasks {
            let occurs = task.occurs(on: day, calendar: calendar)
            let dueToday = task.dueAt.map(inDay) == true
            guard occurs || dueToday else { continue }
            let done = task.isCompleted(on: day, calendar: calendar)
            if let anchor = task.scheduledAt {
                let at = task.repeatRule.date(on: start, preservingTimeFrom: anchor, calendar: calendar)
                guard inDay(at) else { continue }
                let duration = task.plannedDuration ?? 30 * 60
                timed.append(TimelineItem(
                    id: "task-\(task.id.uuidString)-\(Int(start.timeIntervalSinceReferenceDate))",
                    kind: .scheduledTask(task.id), title: task.title, start: at,
                    end: min(at.addingTimeInterval(duration), end), isDone: done, subject: task.subject
                ))
            } else {
                let item = TimelineItem(
                    id: "due-\(task.id.uuidString)-\(Int(start.timeIntervalSinceReferenceDate))",
                    kind: .dueTask(task.id), title: task.title,
                    start: task.dueAt ?? start, end: nil, isDone: done, subject: task.subject
                )
                untimedByPeriod[task.dayPeriod, default: []].append(item)
            }
        }
        for session in sessions where session.state == .completed {
            guard let ended = session.endedAt, inDay(session.startedAt) || inDay(ended) else { continue }
            let subject = session.taskID.flatMap { taskID in tasks.first(where: { $0.id == taskID })?.subject }
            timed.append(TimelineItem(id: "session-\(session.id.uuidString)", kind: .focusSession(session.id),
                                      title: "Focus", start: max(session.startedAt, start), end: min(ended, end),
                                      isDone: true, subject: subject))
        }
        for event in events {
            guard event.startsAt < end && event.endsAt > start else { continue }
            timed.append(TimelineItem(id: "event-\(event.id)", kind: .calendarEvent(event.id),
                                      title: event.title, start: max(event.startsAt, start),
                                      end: min(event.endsAt, end), isDone: false, subject: nil))
        }
        timed.sort { lhs, rhs in
            lhs.start == rhs.start ? lhs.id < rhs.id : lhs.start < rhs.start
        }
        let groups = TaskDayPeriod.allCases.compactMap { period -> TimelineUntimedGroup? in
            let groupItems = (untimedByPeriod[period] ?? []).sorted {
                $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start
            }
            return groupItems.isEmpty ? nil : TimelineUntimedGroup(period: period, items: groupItems)
        }
        return DayTimeline(day: start, untimedGroups: groups, timed: timed)
    }
}

/// Turns a spoken sentence into a task draft: "finish the lab report by
/// Friday" becomes "Finish the lab report", due Friday. Only a few plain
/// endings are understood; anything else stays in the title.
struct SpokenTaskParser {
    var calendar: Calendar

    private static let connectors: Set<String> = ["due", "by", "on", "for"]

    func draft(from transcript: String, now: Date) -> CapturedTaskDraft? {
        var words = transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        let lowered = words.map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }

        var due: Date?
        if let last = lowered.last, let offset = dayOffset(for: last, now: now) {
            var drop = 1
            if lowered.count >= 2, Self.connectors.contains(lowered[lowered.count - 2]) {
                drop = 2
                // "due by Friday", "due on Monday"
                if lowered.count >= 3, lowered[lowered.count - 3] == "due", lowered[lowered.count - 2] != "due" {
                    drop = 3
                }
            }
            // Keep at least one word of title ("Tomorrow" alone stays a title).
            if words.count > drop {
                due = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))
                words.removeLast(drop)
            }
        }

        let title = words.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".,;:")))
        guard let first = title.first else { return nil }
        return CapturedTaskDraft(title: first.uppercased() + title.dropFirst(), dueAt: due, scheduledAt: nil)
    }

    private func dayOffset(for word: String, now: Date) -> Int? {
        switch word {
        case "today", "tonight": return 0
        case "tomorrow": return 1
        default: break
        }
        let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        guard let target = names.firstIndex(of: word) else { return nil }
        let current = calendar.component(.weekday, from: now) - 1
        let delta = target - current
        return delta <= 0 ? delta + 7 : delta
    }
}
