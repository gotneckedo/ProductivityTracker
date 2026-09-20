import Foundation

/// One line a day. Saving again on the same day replaces that day's line, so
/// there is never a backlog to catch up on.
final class JournalController {
    private let clock: Clock
    private let calendar: Calendar
    private let journal: JournalRepository
    private let events: EventTracking
    var onPersistenceError: ((Error) -> Void)?

    init(clock: Clock, calendar: Calendar, journal: JournalRepository, events: EventTracking) {
        self.clock = clock
        self.calendar = calendar
        self.journal = journal
        self.events = events
    }

    var today: Date { calendar.startOfDay(for: clock.now) }

    func entry(on day: Date) -> JournalEntry? {
        let start = calendar.startOfDay(for: day)
        return journal.allEntries().last { calendar.isDate($0.day, inSameDayAs: start) }
    }

    func todaysEntry() -> JournalEntry? {
        entry(on: clock.now)
    }

    /// Newest first, excluding today.
    func pastEntries(limit: Int = 60) -> [JournalEntry] {
        let start = today
        return Array(journal.allEntries()
            .filter { $0.day < start }
            .sorted { $0.day > $1.day }
            .prefix(limit))
    }

    /// Saves today's line. Blank text with no mood removes today's entry.
    @discardableResult
    func saveToday(text raw: String, mood: JournalMood?) -> JournalEntry? {
        let text = Self.normalized(raw)
        let existing = todaysEntry()
        if text.isEmpty && mood == nil {
            if let existing { delete(id: existing.id) }
            return nil
        }
        var entry = existing ?? JournalEntry(id: UUID(), day: today, createdAt: clock.now, text: "", mood: nil)
        let isNew = existing == nil
        entry.text = text
        entry.mood = mood
        do {
            try journal.save(entry)
            if isNew {
                // No text, no mood: only that a line was written.
                events.track(.journalEntrySaved, EventProperties())
            }
            return entry
        } catch {
            onPersistenceError?(error)
            return existing
        }
    }

    func delete(id: UUID) {
        do {
            try journal.delete(id: id)
        } catch {
            onPersistenceError?(error)
        }
    }

    /// Days in a row with a line, counting today or yesterday. Never shaming:
    /// the UI only mentions it when it's above one.
    func currentRun() -> Int {
        let days = Set(journal.allEntries().map { calendar.startOfDay(for: $0.day) })
        return StreakCalculator(calendar: calendar).currentStreak(days: days, today: clock.now)
    }

    /// Collapses whitespace into one line and caps the length.
    static func normalized(_ raw: String) -> String {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(collapsed.prefix(JournalEntry.maximumLength))
    }
}
