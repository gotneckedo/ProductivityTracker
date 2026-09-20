import Foundation

struct GridPoint: Codable, Hashable {
    var row: Int
    var column: Int
}

/// A small word search. Selection is tap-to-select: tap a word's first letter,
/// then its last letter (either order). Straight lines only.
struct WordSearchPuzzle: Codable, Hashable, Identifiable {
    let id: String
    let size: Int
    /// Rows of uppercase letters.
    let rows: [String]
    let words: [String]

    func letter(at point: GridPoint) -> Character? {
        guard contains(point) else { return nil }
        let row = Array(rows[point.row])
        return row[point.column]
    }

    func contains(_ point: GridPoint) -> Bool {
        (0..<size).contains(point.row) && (0..<size).contains(point.column)
    }

    /// Cells on the straight line from `start` to `end`, or nil if not a
    /// horizontal, vertical, or 45° diagonal line.
    func line(from start: GridPoint, to end: GridPoint) -> [GridPoint]? {
        let deltaRow = end.row - start.row
        let deltaColumn = end.column - start.column
        guard deltaRow == 0 || deltaColumn == 0 || abs(deltaRow) == abs(deltaColumn) else { return nil }
        let steps = max(abs(deltaRow), abs(deltaColumn))
        let stepRow = deltaRow.signum()
        let stepColumn = deltaColumn.signum()
        return (0...steps).map { GridPoint(row: start.row + stepRow * $0, column: start.column + stepColumn * $0) }
    }

    func text(along points: [GridPoint]) -> String {
        String(points.compactMap { letter(at: $0) })
    }

    /// Every straight-line occurrence of `word` in all eight directions.
    func occurrences(of word: String) -> [[GridPoint]] {
        let letters = Array(word)
        guard let first = letters.first else { return [] }
        let directions = [(0, 1), (1, 0), (1, 1), (-1, 1), (0, -1), (-1, 0), (-1, -1), (1, -1)]
        var found: [[GridPoint]] = []
        for row in 0..<size {
            for column in 0..<size where letter(at: GridPoint(row: row, column: column)) == first {
                for (dr, dc) in directions {
                    let points = (0..<letters.count).map { GridPoint(row: row + dr * $0, column: column + dc * $0) }
                    if points.allSatisfy(contains), text(along: points) == word {
                        found.append(points)
                    }
                }
            }
        }
        return found
    }
}

enum WordSearchTapResult: Equatable {
    case startedSelection(GridPoint)
    case cleared
    case found(String)
    case noMatch
}

struct WordSearchGame: Codable, Hashable {
    let puzzle: WordSearchPuzzle
    private(set) var foundWords: [String] = []
    /// Cells belonging to found words.
    private(set) var foundCells: Set<GridPoint> = []
    private(set) var pendingStart: GridPoint?

    init(puzzle: WordSearchPuzzle) {
        self.puzzle = puzzle
    }

    var isSolved: Bool { Set(foundWords) == Set(puzzle.words) }

    var hasProgress: Bool { !foundWords.isEmpty }

    mutating func tap(_ point: GridPoint) -> WordSearchTapResult {
        guard puzzle.contains(point), !isSolved else { return .noMatch }
        guard let start = pendingStart else {
            pendingStart = point
            return .startedSelection(point)
        }
        pendingStart = nil
        if start == point { return .cleared }
        guard let points = puzzle.line(from: start, to: point) else { return .noMatch }
        let forward = puzzle.text(along: points)
        let backward = String(forward.reversed())
        for word in puzzle.words where !foundWords.contains(word) && (word == forward || word == backward) {
            foundWords.append(word)
            foundCells.formUnion(points)
            return .found(word)
        }
        return .noMatch
    }
}
