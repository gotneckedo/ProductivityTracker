import Foundation

/// Stable identifier for a collectible room object. String-backed so future catalog additions
/// do not require a persistence migration.
struct RoomObjectID: Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String
    init(_ rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { rawValue = value }
    var description: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum RoomSlot: String, Codable, CaseIterable, Hashable {
    case shelf
    case floorCorner
    case wall
    case windowsill
    case desk

    var displayName: String {
        switch self {
        case .shelf: return "Shelf"
        case .floorCorner: return "Floor corner"
        case .wall: return "Wall"
        case .windowsill: return "Windowsill"
        case .desk: return "Desk"
        }
    }
}

enum RoomObjectRenderKey: String, Codable, Hashable {
    case trailingPlant, deskLamp, artPoster, recordPlayer, wovenRug
    case catBed, stringLights, globe, bookends, bookStack
    case pencilCup, tinyClock, ceramicBird, paperStars, wateringCan
    case floorCushion, pinboard, radio, candle, telescope
}

enum RoomUnlockRule: Hashable, Codable {
    case completedSessions(Int)
    case focusDays(Int)
    case completedReads(Int)
    case savedDoodles(Int)
    case completedActivities(Int)
    case triedActivities(Int)
    case triedCategory(ActivityCategory)
    case triedEveryActivity
    case focusedMinutes(Int)

    var plainLanguage: String {
        switch self {
        case .completedSessions(let count): return count == 1 ? "Finish your first focus session" : "Finish \(count) focus sessions"
        case .focusDays(let count): return "Focus on \(count) days total"
        case .completedReads(let count): return count == 1 ? "Finish your first short read" : "Finish \(count) short reads"
        case .savedDoodles(let count): return count == 1 ? "Save your first doodle" : "Save \(count) doodles"
        case .completedActivities(let count): return count == 1 ? "Finish one break activity" : "Finish \(count) break activities"
        case .triedActivities(let count): return "Try \(count) different break activities"
        case .triedCategory(let category): return "Try every \(category.displayName.lowercased()) activity"
        case .triedEveryActivity: return "Try every break activity once"
        case .focusedMinutes(let count): return "Finish \(count) minutes of focus"
        }
    }
}

/// Catalog metadata is platform-neutral. `renderKey` selects original code-drawn art;
/// `spriteAssetName` is the replacement seam for commissioned art later.
struct RoomObject: Identifiable, Hashable, Codable {
    var id: RoomObjectID
    var name: String
    var summary: String
    var slot: RoomSlot
    var unlockRule: RoomUnlockRule
    var renderKey: RoomObjectRenderKey
    var spriteAssetName: String?
    var sortOrder: Int
}

extension RoomObjectID {
    static let trailingPlant: RoomObjectID = "trailing-plant"
    static let deskLamp: RoomObjectID = "desk-lamp"
    static let artPoster: RoomObjectID = "art-poster"
    static let recordPlayer: RoomObjectID = "record-player"
    static let wovenRug: RoomObjectID = "woven-rug"
    static let catBed: RoomObjectID = "cat-bed"
    static let stringLights: RoomObjectID = "string-lights"
    static let globe: RoomObjectID = "globe"
    static let bookends: RoomObjectID = "bookends"
    static let bookStack: RoomObjectID = "book-stack"
    static let pencilCup: RoomObjectID = "pencil-cup"
    static let tinyClock: RoomObjectID = "tiny-clock"
    static let ceramicBird: RoomObjectID = "ceramic-bird"
    static let paperStars: RoomObjectID = "paper-stars"
    static let wateringCan: RoomObjectID = "watering-can"
    static let floorCushion: RoomObjectID = "floor-cushion"
    static let pinboard: RoomObjectID = "pinboard"
    static let radio: RoomObjectID = "radio"
    static let candle: RoomObjectID = "candle"
    static let telescope: RoomObjectID = "telescope"
}

enum RoomObjectCatalog {
    static let all: [RoomObject] = {
        let values: [RoomObject] = [
        object(.pencilCup, "Pencil cup", "A home for pens and highlighters.", .desk, .completedSessions(1), .pencilCup),
        object(.deskLamp, "Reading lamp", "A small pool of warm light.", .desk, .completedSessions(3), .deskLamp),
        object(.wovenRug, "Woven rug", "A soft shape for the middle of the room.", .floorCorner, .completedSessions(5), .wovenRug),
        object(.trailingPlant, "Trailing plant", "Green leaves for a quiet corner.", .windowsill, .completedSessions(10), .trailingPlant),
        object(.radio, "Small radio", "A tidy little radio for the shelf.", .shelf, .completedSessions(15), .radio),
        object(.floorCushion, "Floor cushion", "A low cushion beside the desk.", .floorCorner, .completedSessions(25), .floorCushion),
        object(.telescope, "Telescope", "A tiny telescope pointed toward the window.", .windowsill, .focusedMinutes(1_000), .telescope),
        object(.candle, "Study candle", "A gentle light for before-bed study.", .desk, .focusDays(3), .candle),
        object(.globe, "Desk globe", "A small world for the shelf.", .shelf, .focusDays(7), .globe),
        object(.stringLights, "String lights", "A warm line of lights across the wall.", .wall, .focusDays(14), .stringLights),
        object(.bookends, "Bookends", "A pair that keeps short reads together.", .shelf, .completedReads(1), .bookends),
        object(.bookStack, "Book stack", "A few finished reads beside the lamp.", .desk, .completedReads(3), .bookStack),
        object(.recordPlayer, "Record player", "A compact player with a warm wood case.", .shelf, .completedReads(10), .recordPlayer),
        object(.artPoster, "Doodle poster", "A simple frame for a creative break.", .wall, .savedDoodles(1), .artPoster),
        object(.paperStars, "Paper stars", "Hand-cut stars for the wall.", .wall, .savedDoodles(3), .paperStars),
        object(.ceramicBird, "Ceramic bird", "A small bird-shaped desk ornament.", .desk, .completedActivities(1), .ceramicBird),
        object(.tinyClock, "Tiny clock", "A clock with no ticking sound.", .shelf, .completedActivities(5), .tinyClock),
        object(.wateringCan, "Watering can", "A little can for the windowsill.", .windowsill, .triedActivities(5), .wateringCan),
        object(.pinboard, "Class pinboard", "A place for a short study note.", .wall, .triedCategory(.puzzle), .pinboard),
        object(.catBed, "Empty cat bed", "A soft round bed, with no character attached.", .floorCorner, .triedEveryActivity, .catBed)
        ]
        return values.enumerated().map { index, value in
            var copy = value
            copy.sortOrder = index
            return copy
        }
    }()

    static func object(_ id: RoomObjectID) -> RoomObject? { all.first { $0.id == id } }

    private static func object(_ id: RoomObjectID, _ name: String, _ summary: String, _ slot: RoomSlot,
                               _ rule: RoomUnlockRule, _ renderKey: RoomObjectRenderKey) -> RoomObject {
        RoomObject(id: id, name: name, summary: summary, slot: slot, unlockRule: rule,
                   renderKey: renderKey, spriteAssetName: nil, sortOrder: 0)
    }
}

/// Retained, user-owned activity totals. No streak or consecutive-day rule is used.
struct RoomActivityHistory: Equatable {
    var completedSessions: Int
    var focusDays: Int
    var completedReads: Int
    var savedDoodles: Int
    var completedActivities: Int
    var triedActivityIDs: Set<BreakActivityID>
    var focusedMinutes: Int

    static let empty = RoomActivityHistory(completedSessions: 0, focusDays: 0, completedReads: 0,
                                           savedDoodles: 0, completedActivities: 0,
                                           triedActivityIDs: [], focusedMinutes: 0)
}

struct RoomUnlockEvaluator {
    func isSatisfied(_ rule: RoomUnlockRule, by history: RoomActivityHistory) -> Bool {
        switch rule {
        case .completedSessions(let count): return history.completedSessions >= count
        case .focusDays(let count): return history.focusDays >= count
        case .completedReads(let count): return history.completedReads >= count
        case .savedDoodles(let count): return history.savedDoodles >= count
        case .completedActivities(let count): return history.completedActivities >= count
        case .triedActivities(let count): return history.triedActivityIDs.count >= count
        case .triedCategory(let category):
            let required = Set(ActivityCatalog.available.filter { $0.category == category }.map(\.id))
            return required.isSubset(of: history.triedActivityIDs)
        case .triedEveryActivity:
            return Set(ActivityCatalog.available.map(\.id)).isSubset(of: history.triedActivityIDs)
        case .focusedMinutes(let count): return history.focusedMinutes >= count
        }
    }

    func earnedIDs(history: RoomActivityHistory) -> Set<RoomObjectID> {
        Set(RoomObjectCatalog.all.filter { isSatisfied($0.unlockRule, by: history) }.map(\.id))
    }
}

struct RoomPlacement: Codable, Hashable, Identifiable {
    var sceneID: SceneID
    var slot: RoomSlot
    var objectID: RoomObjectID
    var id: String { "\(sceneID.rawValue).\(slot.rawValue)" }
}

/// A single persisted record. Missing keys decode to empty values for migration from previews
/// and early builds. Earned IDs are only unioned with new evaluation results, never replaced.
struct RoomCollectionState: Codable, Equatable {
    static let currentSchemaVersion = 1
    var unlockedObjectIDs: Set<RoomObjectID>
    var acknowledgedObjectIDs: Set<RoomObjectID>
    var placements: [RoomPlacement]
    var schemaVersion: Int

    init(unlockedObjectIDs: Set<RoomObjectID> = [], acknowledgedObjectIDs: Set<RoomObjectID> = [],
         placements: [RoomPlacement] = [], schemaVersion: Int = currentSchemaVersion) {
        self.unlockedObjectIDs = unlockedObjectIDs
        self.acknowledgedObjectIDs = acknowledgedObjectIDs
        self.placements = placements
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey { case unlockedObjectIDs, acknowledgedObjectIDs, placements, schemaVersion }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unlockedObjectIDs = try c.decodeIfPresent(Set<RoomObjectID>.self, forKey: .unlockedObjectIDs) ?? []
        acknowledgedObjectIDs = try c.decodeIfPresent(Set<RoomObjectID>.self, forKey: .acknowledgedObjectIDs) ?? []
        placements = try c.decodeIfPresent([RoomPlacement].self, forKey: .placements) ?? []
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
    }
}

enum RoomPlacementFailure: Error, Equatable { case unknownObject, locked, wrongSlot }

final class RoomCollectionController {
    private let repository: RoomCollectionRepository
    private let clock: Clock
    var onPersistenceError: ((Error) -> Void)?

    init(repository: RoomCollectionRepository, clock: Clock) {
        self.repository = repository
        self.clock = clock
    }

    func state() -> RoomCollectionState { repository.load() }

    @discardableResult
    func evaluate(_ history: RoomActivityHistory) -> Set<RoomObjectID> {
        var state = repository.load()
        let earned = RoomUnlockEvaluator().earnedIDs(history: history)
        let newlyEarned = earned.subtracting(state.unlockedObjectIDs)
        guard !newlyEarned.isEmpty else { return [] }
        state.unlockedObjectIDs.formUnion(newlyEarned)
        save(state)
        return newlyEarned
    }

    func place(_ objectID: RoomObjectID, in sceneID: SceneID, slot: RoomSlot) throws {
        guard let object = RoomObjectCatalog.object(objectID) else { throw RoomPlacementFailure.unknownObject }
        var state = repository.load()
        guard state.unlockedObjectIDs.contains(objectID) else { throw RoomPlacementFailure.locked }
        guard object.slot == slot else { throw RoomPlacementFailure.wrongSlot }
        state.placements.removeAll { ($0.sceneID == sceneID && $0.slot == slot) || ($0.sceneID == sceneID && $0.objectID == objectID) }
        state.placements.append(RoomPlacement(sceneID: sceneID, slot: slot, objectID: objectID))
        save(state)
    }

    func remove(from sceneID: SceneID, slot: RoomSlot) {
        var state = repository.load()
        state.placements.removeAll { $0.sceneID == sceneID && $0.slot == slot }
        save(state)
    }

    func acknowledgeUnlocks() {
        var state = repository.load()
        state.acknowledgedObjectIDs.formUnion(state.unlockedObjectIDs)
        save(state)
    }

    private func save(_ state: RoomCollectionState) {
        do { try repository.save(state, at: clock.now) }
        catch { onPersistenceError?(error) }
    }
}

protocol RoomCollectionRepository: AnyObject {
    func load() -> RoomCollectionState
    func save(_ state: RoomCollectionState, at date: Date) throws
}

final class StoredRoomCollectionRepository: RoomCollectionRepository {
    private let store: RecordStore
    private let id = "room-collection"
    init(store: RecordStore) { self.store = store }

    func load() -> RoomCollectionState {
        guard let record = try? store.fetch(kind: .roomCollection, id: id) else { return RoomCollectionState() }
        return (try? RecordCoding.decoder().decode(RoomCollectionState.self, from: record.payload)) ?? RoomCollectionState()
    }

    func save(_ state: RoomCollectionState, at date: Date) throws {
        let existing = try? store.fetch(kind: .roomCollection, id: id)
        try store.upsert(StoredRecord(id: id, kind: .roomCollection,
                                     createdAt: existing?.createdAt ?? date, updatedAt: date,
                                     schemaVersion: RoomCollectionState.currentSchemaVersion,
                                     payload: try RecordCoding.encoder().encode(state)))
    }
}

extension RoomActivityHistory {
    static func make(sessions: [FocusSession], usages: [ActivityUsage], readingProgress: [ReadingProgress],
                     doodles: [ActivityArtifact], calendar: Calendar) -> RoomActivityHistory {
        let completedSessions = sessions.filter { $0.state == .completed }
        let completedUsages = usages.filter { $0.outcome == .completed }
        let focusDays = Set(completedSessions.map { calendar.startOfDay(for: $0.endedAt ?? $0.startedAt) }).count
        let activityReads = completedUsages.filter { $0.activityID == .shortRead }.count
        let storedReads = readingProgress.reduce(0) { $0 + $1.finishedSittings }
        let seconds = completedSessions.reduce(0.0) { $0 + $1.countedFocusDuration }
        return RoomActivityHistory(
            completedSessions: completedSessions.count,
            focusDays: focusDays,
            completedReads: max(activityReads, storedReads),
            savedDoodles: doodles.filter { $0.doodle?.isBlank == false }.count,
            completedActivities: completedUsages.count,
            triedActivityIDs: Set(usages.map(\.activityID)),
            focusedMinutes: Int(seconds / 60)
        )
    }
}
