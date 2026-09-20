import Foundation

enum ActivityOutcome: String, Codable, Hashable {
    case inProgress
    case completed
    case abandoned
}

enum ActivityEntryPoint: String, Codable, Hashable {
    /// Picked from the three session-complete suggestions.
    case suggestion
    /// Picked from the Break shelf.
    case shelf
}

/// Where an activity was opened from. Part of the `breakActivity` route.
struct ActivityContext: Codable, Hashable {
    var entryPoint: ActivityEntryPoint
    var sessionID: UUID?
    /// 0-based position among the three suggestions, when relevant.
    var suggestionRank: Int?

    static let shelf = ActivityContext(entryPoint: .shelf, sessionID: nil, suggestionRank: nil)
}

/// One opening of an activity, from start to finish.
struct ActivityUsage: Codable, Identifiable, Hashable {
    var id: UUID
    var activityID: BreakActivityID
    var startedAt: Date
    var endedAt: Date?
    var outcome: ActivityOutcome
    var context: ActivityContext
}

enum ActivityNoteKind: String, Codable, Hashable {
    case brainDump
    case creativeResponse
}

/// Text saved by a Reset or Quiet activity. Stays on device; never analytics.
/// V1.1 doodles will add a sibling artifact type rather than overload this.
struct ActivityNote: Codable, Identifiable, Hashable {
    var id: UUID
    var activityID: BreakActivityID
    var kind: ActivityNoteKind
    var createdAt: Date
    var updatedAt: Date
    var text: String
    /// The creative prompt answered, when relevant.
    var promptID: String?
}
