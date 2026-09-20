import Foundation

/// Suggestions, activity usage, and activity notes.
final class BreakFlowController {
    private let clock: Clock
    private let calendar: Calendar
    private let usages: ActivityUsageRepository
    private let notes: ActivityNoteRepository
    private let events: EventTracking
    private let engine: BreakSuggestionEngine
    private let catalog: [BreakActivity]

    /// Default break offered after count-up sessions and outside a session.
    static let defaultBreak: TimeInterval = 5 * 60

    var onPersistenceError: ((Error) -> Void)?

    init(
        clock: Clock,
        calendar: Calendar,
        usages: ActivityUsageRepository,
        notes: ActivityNoteRepository,
        events: EventTracking,
        engine: BreakSuggestionEngine = BreakSuggestionEngine(),
        catalog: [BreakActivity] = ActivityCatalog.all
    ) {
        self.clock = clock
        self.calendar = calendar
        self.usages = usages
        self.notes = notes
        self.events = events
        self.engine = engine
        self.catalog = catalog
    }

    // MARK: - Suggestions

    func usedToday() -> Set<BreakActivityID> {
        Set(usages.allUsages()
            .filter { calendar.isDate($0.startedAt, inSameDayAs: clock.now) }
            .map(\.activityID))
    }

    /// Exactly three suggestions (when the catalog allows), personalized and
    /// time-appropriate. Tracks `break_suggestions_presented` when asked.
    func suggestions(after session: FocusSession?, personalization: Personalization, trackPresentation: Bool) -> BreakSuggestionSet {
        let allUsages = usages.allUsages()
        var lastUsed: [BreakActivityID: Date] = [:]
        for usage in allUsages {
            lastUsed[usage.activityID] = max(lastUsed[usage.activityID] ?? .distantPast, usage.startedAt)
        }
        let breakTime: TimeInterval
        if let session, session.configuration.mode != .countUp {
            breakTime = session.configuration.suggestedBreakDuration
        } else {
            breakTime = Self.defaultBreak
        }
        let request = BreakSuggestionRequest(
            availableBreak: breakTime,
            catalog: catalog,
            usedToday: usedToday(),
            lastUsedAt: lastUsed,
            categoryOrder: personalization.categoryOrder,
            daySeed: calendar.ordinality(of: .day, in: .year, for: clock.now) ?? 0
        )
        let result = engine.suggestions(for: request)
        if trackPresentation {
            events.track(.breakSuggestionsPresented, EventProperties()
                .count(result.activities.count)
                .duration(breakTime))
        }
        return result
    }

    // MARK: - Usage

    @discardableResult
    func begin(_ activityID: BreakActivityID, context: ActivityContext) -> ActivityUsage {
        let usage = ActivityUsage(
            id: UUID(),
            activityID: activityID,
            startedAt: clock.now,
            endedAt: nil,
            outcome: .inProgress,
            context: context
        )
        persist(usage)
        var properties = EventProperties().activity(activityID).entryPoint(context.entryPoint).userInitiated(true)
        if let rank = context.suggestionRank {
            properties = properties.suggestionRank(rank)
        }
        events.track(.breakActivityStarted, properties)
        return usage
    }

    /// Records the end of an activity. Idempotent: an already-finished usage is left alone.
    func finish(usageID: UUID, outcome: ActivityOutcome) {
        guard outcome != .inProgress, var usage = usages.usage(id: usageID), usage.outcome == .inProgress else { return }
        usage.outcome = outcome
        usage.endedAt = clock.now
        persist(usage)
        let properties = EventProperties()
            .activity(usage.activityID)
            .duration(clock.now.timeIntervalSince(usage.startedAt))
            .userInitiated(true)
        events.track(outcome == .completed ? .breakActivityCompleted : .breakActivityAbandoned, properties)
    }

    /// Closes usages left open by a crash or force-quit, as abandoned.
    func closeStaleUsages() {
        for usage in usages.allUsages() where usage.outcome == .inProgress {
            var closed = usage
            closed.outcome = .abandoned
            closed.endedAt = clock.now
            persist(closed)
        }
    }

    // MARK: - Notes

    /// Saves text from Brain Dump or Creative Prompt. Empty text is not saved.
    @discardableResult
    func saveNote(text: String, kind: ActivityNoteKind, activityID: BreakActivityID, promptID: String?, existingID: UUID? = nil) -> ActivityNote? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let now = clock.now
        let note = ActivityNote(
            id: existingID ?? UUID(),
            activityID: activityID,
            kind: kind,
            createdAt: existingID.flatMap { id in notes.notes(kind: kind).first { $0.id == id }?.createdAt } ?? now,
            updatedAt: now,
            text: trimmed,
            promptID: promptID
        )
        do {
            try notes.save(note)
            return note
        } catch {
            onPersistenceError?(error)
            return nil
        }
    }

    /// Removes a note the user cleared completely (autosave's "empty" state).
    func deleteNote(id: UUID) {
        do {
            try notes.delete(id: id)
        } catch {
            onPersistenceError?(error)
        }
    }

    func recentNotes(kind: ActivityNoteKind, limit: Int = 5) -> [ActivityNote] {
        Array(notes.notes(kind: kind).prefix(limit))
    }

    private func persist(_ usage: ActivityUsage) {
        do {
            try usages.save(usage)
        } catch {
            onPersistenceError?(error)
        }
    }
}
