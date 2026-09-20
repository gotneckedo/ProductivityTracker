import Foundation

extension Identifier where Tag == BreakActivityTag {
    static let sudoku: BreakActivityID = "sudoku"
    static let picross: BreakActivityID = "picross"
    static let wordSearch: BreakActivityID = "wordSearch"
    static let shortRead: BreakActivityID = "shortRead"
    static let creativePrompt: BreakActivityID = "creativePrompt"
    static let brainDump: BreakActivityID = "brainDump"
    static let guidedStretch: BreakActivityID = "guidedStretch"
    static let boxBreathing: BreakActivityID = "boxBreathing"
    static let doNothing: BreakActivityID = "doNothing"
}

enum ActivityCategory: String, Codable, CaseIterable, Hashable {
    case puzzle
    case quiet
    case reset

    var displayName: String {
        switch self {
        case .puzzle: return "Puzzle"
        case .quiet: return "Quiet"
        case .reset: return "Reset"
        }
    }

    var sortOrder: Int {
        switch self {
        case .puzzle: return 0
        case .quiet: return 1
        case .reset: return 2
        }
    }
}

enum ActivityImplementationState: String, Codable, Hashable {
    /// Built and shown on the shelf.
    case available
    /// Defined for planning only. Never shown in the V1 UI.
    case planned
}

/// A finite thing to do instead of scrolling.
struct BreakActivity: Codable, Identifiable, Hashable {
    var id: BreakActivityID
    var name: String
    var category: ActivityCategory
    var summary: String
    var estimatedDuration: TimeInterval
    var implementationState: ActivityImplementationState
    /// SF Symbol name used for the tile. Symbols, not emoji.
    var symbolName: String
    var sortOrder: Int

    var estimatedMinutes: Int {
        max(1, Int((estimatedDuration / 60).rounded(.up)))
    }
}
