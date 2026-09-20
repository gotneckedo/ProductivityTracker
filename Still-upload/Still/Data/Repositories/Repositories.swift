import Foundation

// Small, injectable repositories. Each one owns a single collection and hides
// the storage format from features.

protocol SessionRepository: AnyObject {
    func save(_ session: FocusSession) throws
    func session(id: UUID) -> FocusSession?
    func allSessions() -> [FocusSession]
    /// The one active or paused session, if any.
    func liveSession() -> FocusSession?
}

protocol TaskRepository: AnyObject {
    func save(_ task: TaskItem) throws
    func task(id: UUID) -> TaskItem?
    func allTasks() -> [TaskItem]
    func delete(id: UUID) throws
}

protocol ActivityUsageRepository: AnyObject {
    func save(_ usage: ActivityUsage) throws
    func usage(id: UUID) -> ActivityUsage?
    func allUsages() -> [ActivityUsage]
}

protocol ActivityNoteRepository: AnyObject {
    func save(_ note: ActivityNote) throws
    func notes(kind: ActivityNoteKind) -> [ActivityNote]
    func delete(id: UUID) throws
}

/// V1.1 journal boundary. Implemented and tested; not exposed in the V1 UI.
protocol JournalRepository: AnyObject {
    func save(_ entry: JournalEntry) throws
    func allEntries() -> [JournalEntry]
}

/// Saved in-progress puzzle state, so leaving an activity never loses work.
protocol PuzzleProgressRepository: AnyObject {
    func load<State: Codable>(_ type: State.Type, puzzleID: String) -> State?
    func save<State: Codable>(_ state: State, puzzleID: String, at date: Date) throws
    func clear(puzzleID: String) throws
}

/// A Codable-over-RecordStore collection used by the concrete repositories.
final class RecordCollection<Element: Codable> {
    private let store: RecordStore
    private let kind: RecordKind
    private let schemaVersion: Int
    private let encoder = RecordCoding.encoder()
    private let decoder = RecordCoding.decoder()

    init(store: RecordStore, kind: RecordKind, schemaVersion: Int = 1) {
        self.store = store
        self.kind = kind
        self.schemaVersion = schemaVersion
    }

    func save(_ element: Element, id: String, createdAt: Date, updatedAt: Date) throws {
        let payload = try encoder.encode(element)
        try store.upsert(StoredRecord(id: id, kind: kind, createdAt: createdAt, updatedAt: updatedAt,
                                      schemaVersion: schemaVersion, payload: payload))
    }

    func element(id: String) -> Element? {
        guard let record = try? store.fetch(kind: kind, id: id) else { return nil }
        return try? decoder.decode(Element.self, from: record.payload)
    }

    /// Records that fail to decode are skipped rather than crashing the app.
    func all() -> [Element] {
        let records = (try? store.fetchAll(kind: kind)) ?? []
        return records.compactMap { try? decoder.decode(Element.self, from: $0.payload) }
    }

    func delete(id: String) throws {
        try store.delete(kind: kind, id: id)
    }
}

final class StoredSessionRepository: SessionRepository {
    private let collection: RecordCollection<FocusSession>

    init(store: RecordStore) {
        collection = RecordCollection(store: store, kind: .session, schemaVersion: FocusSession.currentSchemaVersion)
    }

    func save(_ session: FocusSession) throws {
        try collection.save(session, id: session.id.uuidString, createdAt: session.createdAt,
                            updatedAt: session.endedAt ?? session.phaseStartedAt)
    }

    func session(id: UUID) -> FocusSession? {
        collection.element(id: id.uuidString)
    }

    func allSessions() -> [FocusSession] {
        collection.all().sorted { $0.startedAt < $1.startedAt }
    }

    func liveSession() -> FocusSession? {
        allSessions().last { $0.state.isLive }
    }
}

final class StoredTaskRepository: TaskRepository {
    private let collection: RecordCollection<TaskItem>

    init(store: RecordStore) {
        collection = RecordCollection(store: store, kind: .task)
    }

    func save(_ task: TaskItem) throws {
        try collection.save(task, id: task.id.uuidString, createdAt: task.createdAt,
                            updatedAt: task.completedAt ?? task.createdAt)
    }

    func task(id: UUID) -> TaskItem? {
        collection.element(id: id.uuidString)
    }

    func allTasks() -> [TaskItem] {
        collection.all().sorted { $0.createdAt < $1.createdAt }
    }

    func delete(id: UUID) throws {
        try collection.delete(id: id.uuidString)
    }
}

final class StoredActivityUsageRepository: ActivityUsageRepository {
    private let collection: RecordCollection<ActivityUsage>

    init(store: RecordStore) {
        collection = RecordCollection(store: store, kind: .activityUsage)
    }

    func save(_ usage: ActivityUsage) throws {
        try collection.save(usage, id: usage.id.uuidString, createdAt: usage.startedAt,
                            updatedAt: usage.endedAt ?? usage.startedAt)
    }

    func usage(id: UUID) -> ActivityUsage? {
        collection.element(id: id.uuidString)
    }

    func allUsages() -> [ActivityUsage] {
        collection.all().sorted { $0.startedAt < $1.startedAt }
    }
}

final class StoredActivityNoteRepository: ActivityNoteRepository {
    private let collection: RecordCollection<ActivityNote>

    init(store: RecordStore) {
        collection = RecordCollection(store: store, kind: .activityNote)
    }

    func save(_ note: ActivityNote) throws {
        try collection.save(note, id: note.id.uuidString, createdAt: note.createdAt, updatedAt: note.updatedAt)
    }

    func notes(kind: ActivityNoteKind) -> [ActivityNote] {
        collection.all().filter { $0.kind == kind }.sorted { $0.createdAt > $1.createdAt }
    }

    func delete(id: UUID) throws {
        try collection.delete(id: id.uuidString)
    }
}

final class StoredJournalRepository: JournalRepository {
    private let collection: RecordCollection<JournalEntry>

    init(store: RecordStore) {
        collection = RecordCollection(store: store, kind: .journalEntry)
    }

    func save(_ entry: JournalEntry) throws {
        try collection.save(entry, id: entry.id.uuidString, createdAt: entry.createdAt, updatedAt: entry.createdAt)
    }

    func allEntries() -> [JournalEntry] {
        collection.all().sorted { $0.day < $1.day }
    }
}

final class StoredPuzzleProgressRepository: PuzzleProgressRepository {
    private let store: RecordStore
    private let encoder = RecordCoding.encoder()
    private let decoder = RecordCoding.decoder()

    init(store: RecordStore) {
        self.store = store
    }

    func load<State: Codable>(_ type: State.Type, puzzleID: String) -> State? {
        guard let record = try? store.fetch(kind: .puzzleProgress, id: puzzleID) else { return nil }
        return try? decoder.decode(State.self, from: record.payload)
    }

    func save<State: Codable>(_ state: State, puzzleID: String, at date: Date) throws {
        let payload = try encoder.encode(state)
        let existing = try? store.fetch(kind: .puzzleProgress, id: puzzleID)
        try store.upsert(StoredRecord(id: puzzleID, kind: .puzzleProgress, createdAt: existing?.createdAt ?? date,
                                      updatedAt: date, schemaVersion: 1, payload: payload))
    }

    func clear(puzzleID: String) throws {
        try store.delete(kind: .puzzleProgress, id: puzzleID)
    }
}
