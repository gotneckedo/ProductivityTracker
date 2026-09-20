import Foundation

/// V1.1 one-line journal. Model and repository exist; no V1 UI.
enum JournalMood: String, Codable, CaseIterable, Hashable {
    case calm
    case okay
    case heavy
    case bright
}

struct JournalEntry: Codable, Identifiable, Hashable {
    var id: UUID
    /// Start of the calendar day the entry belongs to.
    var day: Date
    var createdAt: Date
    var text: String
    var mood: JournalMood?
}
