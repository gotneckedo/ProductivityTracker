import Foundation

/// Collections persisted by the app.
enum RecordKind: String, CaseIterable {
    case session
    case task
    case activityUsage
    case activityNote
    case journalEntry
    case puzzleProgress
    case habit
    case habitCheckIn
    case activityArtifact
    case readingProgress
}

struct StoredRecord: Equatable {
    var id: String
    var kind: RecordKind
    var createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int
    var payload: Data
}

/// The lowest persistence boundary: a small document store.
///
/// Domain types are `Codable`; repositories encode them into records. V1 backs
/// this with SwiftData (`SwiftDataRecordStore`); tests and previews use
/// `InMemoryRecordStore`. A sync layer or a different database only needs to
/// implement this protocol.
protocol RecordStore: AnyObject {
    func upsert(_ record: StoredRecord) throws
    func fetchAll(kind: RecordKind) throws -> [StoredRecord]
    func fetch(kind: RecordKind, id: String) throws -> StoredRecord?
    func delete(kind: RecordKind, id: String) throws
    func deleteAll() throws
}

final class InMemoryRecordStore: RecordStore {
    private var records: [RecordKind: [String: StoredRecord]] = [:]
    /// Set to simulate a disk failure in tests.
    var failsWrites = false

    struct SimulatedFailure: Error {}

    func upsert(_ record: StoredRecord) throws {
        if failsWrites { throw SimulatedFailure() }
        records[record.kind, default: [:]][record.id] = record
    }

    func fetchAll(kind: RecordKind) throws -> [StoredRecord] {
        (records[kind] ?? [:]).values.sorted { $0.createdAt < $1.createdAt }
    }

    func fetch(kind: RecordKind, id: String) throws -> StoredRecord? {
        records[kind]?[id]
    }

    func delete(kind: RecordKind, id: String) throws {
        if failsWrites { throw SimulatedFailure() }
        records[kind]?[id] = nil
    }

    func deleteAll() throws {
        if failsWrites { throw SimulatedFailure() }
        records.removeAll()
    }
}

/// Shared JSON coding for records. Dates are stored as reference-date seconds
/// (typed values, not formatted strings).
enum RecordCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }
}

/// Small key-value boundary for preferences and presets.
protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

final class UserDefaultsKeyValueStore: KeyValueStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Data] = [:]

    func data(forKey key: String) -> Data? { storage[key] }

    func set(_ data: Data?, forKey key: String) {
        storage[key] = data
    }
}
