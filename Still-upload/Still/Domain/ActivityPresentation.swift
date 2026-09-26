import Foundation

/// A named visual family for a finite break activity. SwiftUI converts the
/// palette values to `Color`; keeping this model platform-neutral makes the
/// complete catalog mapping testable with `swift test`.
enum ActivityVisualTone: String, Codable, CaseIterable, Hashable {
    case sky
    case lavender
    case butter
    case peach
    case rose
    case mint
    case parchment
    case leaf
    case periwinkle
    case linen
}

struct ActivityVisualStyle: Codable, Hashable {
    let tone: ActivityVisualTone
    let glowHex: UInt32
    let accentHex: UInt32
    let darkAccentHex: UInt32
}

struct ActivityStatusData: Equatable {
    var completedCount: Int = 0
    var hasSavedProgress = false
    var latestTitle: String?
    var artifactCount = 0
}

enum ActivityStatusKind: String, Codable, Hashable {
    case fresh
    case inProgress
    case completed
    case collection
}

struct ActivityStatus: Equatable {
    let text: String
    let kind: ActivityStatusKind
}

enum SudokuCellEmphasis: Equatable {
    case none
    case peer
    case matchingNumber
    case conflict
    case selected
}

/// Visual and status copy live outside the activity definitions so product
/// styling can evolve without changing behavior, persistence, or puzzle data.
enum ActivityPresentation {
    static func visualStyle(for id: BreakActivityID) -> ActivityVisualStyle {
        switch id {
        case .sudoku:
            return ActivityVisualStyle(tone: .sky, glowHex: 0x9ECDE6, accentHex: 0x6C63C8, darkAccentHex: 0xC4BCF6)
        case .picross:
            return ActivityVisualStyle(tone: .lavender, glowHex: 0xB8A6DE, accentHex: 0x7663A8, darkAccentHex: 0xD2C8F2)
        case .wordSearch:
            return ActivityVisualStyle(tone: .butter, glowHex: 0xF1D688, accentHex: 0x977321, darkAccentHex: 0xF6DEA0)
        case .shortRead:
            return ActivityVisualStyle(tone: .peach, glowHex: 0xF4B89C, accentHex: 0xA95F47, darkAccentHex: 0xF7C4AC)
        case .creativePrompt:
            return ActivityVisualStyle(tone: .rose, glowHex: 0xE9A6B0, accentHex: 0x9E5264, darkAccentHex: 0xF0BBC3)
        case .pixelDoodle:
            return ActivityVisualStyle(tone: .mint, glowHex: 0x8FD1B5, accentHex: 0x3E8F74, darkAccentHex: 0xA6E3CC)
        case .brainDump:
            return ActivityVisualStyle(tone: .parchment, glowHex: 0xE3C9A4, accentHex: 0x8A6948, darkAccentHex: 0xEAD5B8)
        case .guidedStretch:
            return ActivityVisualStyle(tone: .leaf, glowHex: 0xA9C99E, accentHex: 0x567F55, darkAccentHex: 0xBDDBB3)
        case .boxBreathing:
            return ActivityVisualStyle(tone: .periwinkle, glowHex: 0xA9C4EC, accentHex: 0x557BAF, darkAccentHex: 0xC1D5F3)
        case .doNothing:
            return ActivityVisualStyle(tone: .linen, glowHex: 0xE8DCCB, accentHex: 0x806F61, darkAccentHex: 0xEEE4D6)
        default:
            return ActivityVisualStyle(tone: .linen, glowHex: 0xE8DCCB, accentHex: 0x806F61, darkAccentHex: 0xEEE4D6)
        }
    }

    static func status(for id: BreakActivityID, data: ActivityStatusData = ActivityStatusData()) -> ActivityStatus {
        if data.hasSavedProgress {
            return ActivityStatus(text: "Saved progress", kind: .inProgress)
        }

        if data.completedCount > 0 {
            let noun = data.completedCount == 1 ? "once" : "\(data.completedCount) times"
            switch id {
            case .sudoku, .picross, .wordSearch:
                return ActivityStatus(text: "Solved \(noun)", kind: .completed)
            default:
                return ActivityStatus(text: "Finished \(noun)", kind: .completed)
            }
        }

        switch id {
        case .shortRead:
            if let latestTitle = data.latestTitle, !latestTitle.isEmpty {
                return ActivityStatus(text: "Today: \(latestTitle)", kind: .collection)
            }
            return ActivityStatus(text: "A short public-domain read", kind: .fresh)
        case .pixelDoodle:
            if data.artifactCount > 0 {
                let noun = data.artifactCount == 1 ? "doodle" : "doodles"
                return ActivityStatus(text: "\(data.artifactCount) \(noun) on your wall", kind: .collection)
            }
            return ActivityStatus(text: "Your wall is empty", kind: .fresh)
        case .sudoku:
            return ActivityStatus(text: "A fresh 6 × 6", kind: .fresh)
        case .picross:
            return ActivityStatus(text: "A small picture puzzle", kind: .fresh)
        case .wordSearch:
            return ActivityStatus(text: "Six quiet words", kind: .fresh)
        case .creativePrompt:
            return ActivityStatus(text: "A new prompt today", kind: .fresh)
        case .brainDump:
            return ActivityStatus(text: "Saved only on this device", kind: .fresh)
        case .guidedStretch:
            return ActivityStatus(text: "Four gentle steps", kind: .fresh)
        case .boxBreathing:
            return ActivityStatus(text: "Two quiet minutes", kind: .fresh)
        case .doNothing:
            return ActivityStatus(text: "One minute with no task", kind: .fresh)
        default:
            return ActivityStatus(text: "Ready when you are", kind: .fresh)
        }
    }
}

/// A lightweight, non-persisted undo stack. Persisted `SudokuGame` remains
/// backward compatible; a restored puzzle simply starts a new undo history.
struct SudokuMoveHistory: Equatable {
    private(set) var snapshots: [SudokuGame] = []

    var canUndo: Bool { !snapshots.isEmpty }

    mutating func record(_ game: SudokuGame) {
        snapshots.append(game)
    }

    @discardableResult
    mutating func undo(current: inout SudokuGame) -> Bool {
        guard let previous = snapshots.popLast() else { return false }
        current = previous
        return true
    }

    mutating func clear() {
        snapshots.removeAll()
    }
}

extension SudokuGame {
    /// Visual priority is deterministic: selection, then conflict, then equal
    /// number, then a subtle row/column/box relationship.
    func emphasis(at index: Int) -> SudokuCellEmphasis {
        guard puzzle.givens.indices.contains(index) else { return .none }
        if selectedIndex == index { return .selected }
        if conflictingIndices.contains(index) { return .conflict }
        guard let selectedIndex else { return .none }
        if let selectedValue = value(at: selectedIndex), selectedValue == value(at: index) {
            return .matchingNumber
        }
        if puzzle.peers(of: selectedIndex).contains(index) { return .peer }
        return .none
    }
}
