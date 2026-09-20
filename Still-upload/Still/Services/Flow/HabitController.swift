import Foundation

/// Small daily habits. Checking in is one tap; missing a day is never
/// mentioned. Runs use the same focus-day rule as sessions.
final class HabitController {
    private let clock: Clock
    private let calendar: Calendar
    private let habits: HabitRepository
    private let events: EventTracking
    var onPersistenceError: ((Error) -> Void)?

    init(clock: Clock, calendar: Calendar, habits: HabitRepository, events: EventTracking) {
        self.clock = clock
        self.calendar = calendar
        self.habits = habits
        self.events = events
    }

    var activeHabits: [HabitDefinition] {
        habits.allHabits().filter { !$0.isArchived }
    }

    var canAddHabit: Bool {
        activeHabits.count < HabitDefinition.maximumActive
    }

    @discardableResult
    func create(title raw: String) -> HabitDefinition? {
        guard canAddHabit, let title = Self.normalizedTitle(raw) else { return nil }
        let nextOrder = (habits.allHabits().map(\.sortOrder).max() ?? -1) + 1
        let habit = HabitDefinition(id: UUID(), title: title, createdAt: clock.now, sortOrder: nextOrder, archivedAt: nil)
        return persist { try habits.save(habit) } ? habit : nil
    }

    func rename(id: UUID, to raw: String) {
        guard let title = Self.normalizedTitle(raw),
              var habit = habits.allHabits().first(where: { $0.id == id }) else { return }
        habit.title = title
        persist { try habits.save(habit) }
    }

    /// Keeps the history and removes the habit from the daily list.
    func archive(id: UUID) {
        guard var habit = habits.allHabits().first(where: { $0.id == id }) else { return }
        habit.archivedAt = clock.now
        persist { try habits.save(habit) }
    }

    func delete(id: UUID) {
        persist { try habits.delete(id: id) }
    }

    func isDone(habitID: UUID, on day: Date) -> Bool {
        let start = calendar.startOfDay(for: day)
        return habits.checkIns(habitID: habitID).contains { calendar.isDate($0.day, inSameDayAs: start) }
    }

    /// Toggles today's check-in for a habit.
    func toggleToday(habitID: UUID) {
        setDone(habitID: habitID, on: clock.now, !isDone(habitID: habitID, on: clock.now))
    }

    func setDone(habitID: UUID, on day: Date, _ done: Bool) {
        let start = calendar.startOfDay(for: day)
        let existing = habits.checkIns(habitID: habitID).filter { calendar.isDate($0.day, inSameDayAs: start) }
        if done {
            guard existing.isEmpty else { return }
            if persist({ try habits.save(HabitCheckIn(habitID: habitID, day: start, createdAt: clock.now)) }) {
                events.track(.habitCheckedIn, EventProperties())
            }
        } else {
            for checkIn in existing {
                persist { try habits.deleteCheckIn(id: checkIn.id) }
            }
        }
    }

    /// Today's list, in order, with runs and the last seven days.
    func today() -> [HabitDay] {
        let today = calendar.startOfDay(for: clock.now)
        let streaks = StreakCalculator(calendar: calendar)
        return activeHabits.map { habit in
            let days = Set(habits.checkIns(habitID: habit.id).map { calendar.startOfDay(for: $0.day) })
            let lastSeven: [Bool] = (0..<7).reversed().map { offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
                return days.contains(day)
            }
            return HabitDay(
                habit: habit,
                isDoneToday: days.contains(today),
                currentRun: streaks.currentStreak(days: days, today: clock.now),
                lastSevenDays: lastSeven
            )
        }
    }

    /// Plain words, only when there's something kind to say.
    static func runLine(_ run: Int) -> String? {
        run >= 2 ? "\(run) days in a row" : nil
    }

    static func normalizedTitle(_ raw: String) -> String? {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(HabitDefinition.maximumTitleLength))
    }

    @discardableResult
    private func persist(_ work: () throws -> Void) -> Bool {
        do {
            try work()
            return true
        } catch {
            onPersistenceError?(error)
            return false
        }
    }
}
