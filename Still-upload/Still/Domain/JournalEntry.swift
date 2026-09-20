import Foundation

/// An optional one-word feeling beside the journal line. Never scored.
enum JournalMood: String, Codable, CaseIterable, Hashable {
    case calm
    case okay
    case heavy
    case bright

    var displayName: String {
        switch self {
        case .calm: return "Calm"
        case .okay: return "Okay"
        case .heavy: return "Heavy"
        case .bright: return "Bright"
        }
    }

    /// SF Symbols, not emoji.
    var symbolName: String {
        switch self {
        case .calm: return "leaf"
        case .okay: return "circle"
        case .heavy: return "cloud"
        case .bright: return "sun.max"
        }
    }
}

/// One line for one day. Stays on this device and never reaches analytics.
struct JournalEntry: Codable, Identifiable, Hashable {
    var id: UUID
    /// Start of the calendar day the entry belongs to.
    var day: Date
    var createdAt: Date
    var text: String
    var mood: JournalMood?

    /// One line, not a diary page.
    static let maximumLength = 280
}
