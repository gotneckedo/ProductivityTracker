#if canImport(SwiftData)
import Foundation
import SwiftData

/// One persisted domain object. The payload is the Codable domain value;
/// indexed columns allow fetching by collection and ordering by date.
@Model
final class LocalRecord {
    /// "<kind>:<id>" — unique across the store.
    @Attribute(.unique) var compositeKey: String
    var recordID: String
    var kind: String
    var createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int
    var payload: Data

    init(compositeKey: String, recordID: String, kind: String, createdAt: Date, updatedAt: Date, schemaVersion: Int, payload: Data) {
        self.compositeKey = compositeKey
        self.recordID = recordID
        self.kind = kind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.payload = payload
    }
}

/// SwiftData-backed `RecordStore`. Uses its own `ModelContext` with explicit
/// saves so every write is durable before the call returns.
final class SwiftDataRecordStore: RecordStore {
    let container: ModelContainer
    private let context: ModelContext

    init(inMemory: Bool = false) throws {
        let schema = Schema([LocalRecord.self])
        let configuration = ModelConfiguration("Still", schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    private static func compositeKey(_ kind: RecordKind, _ id: String) -> String {
        "\(kind.rawValue):\(id)"
    }

    func upsert(_ record: StoredRecord) throws {
        let key = Self.compositeKey(record.kind, record.id)
        if let existing = try model(forKey: key) {
            existing.updatedAt = record.updatedAt
            existing.schemaVersion = record.schemaVersion
            existing.payload = record.payload
        } else {
            context.insert(LocalRecord(
                compositeKey: key,
                recordID: record.id,
                kind: record.kind.rawValue,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                schemaVersion: record.schemaVersion,
                payload: record.payload
            ))
        }
        try context.save()
    }

    func fetchAll(kind: RecordKind) throws -> [StoredRecord] {
        let rawKind = kind.rawValue
        let descriptor = FetchDescriptor<LocalRecord>(
            predicate: #Predicate<LocalRecord> { $0.kind == rawKind },
            sortBy: [SortDescriptor(\LocalRecord.createdAt)]
        )
        return try context.fetch(descriptor).compactMap(Self.makeRecord)
    }

    func fetch(kind: RecordKind, id: String) throws -> StoredRecord? {
        try model(forKey: Self.compositeKey(kind, id)).flatMap(Self.makeRecord)
    }

    func delete(kind: RecordKind, id: String) throws {
        if let existing = try model(forKey: Self.compositeKey(kind, id)) {
            context.delete(existing)
            try context.save()
        }
    }

    func deleteAll() throws {
        try context.delete(model: LocalRecord.self)
        try context.save()
    }

    private func model(forKey key: String) throws -> LocalRecord? {
        var descriptor = FetchDescriptor<LocalRecord>(predicate: #Predicate<LocalRecord> { $0.compositeKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func makeRecord(_ model: LocalRecord) -> StoredRecord? {
        guard let kind = RecordKind(rawValue: model.kind) else { return nil }
        return StoredRecord(
            id: model.recordID,
            kind: kind,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            schemaVersion: model.schemaVersion,
            payload: model.payload
        )
    }
}
#endif
