import Foundation

/// A nonogram. Clues are derived from the solution so they can never disagree.
struct PicrossPuzzle: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let size: Int
    /// Row-major solution; true means filled.
    let solution: [Bool]

    /// Parses rows where `#` is filled and anything else is empty.
    init(id: String, title: String, rows: [String]) {
        self.id = id
        self.title = title
        self.size = rows.count
        self.solution = rows.flatMap { row in row.map { $0 == "#" } }
    }

    var rowClues: [[Int]] {
        (0..<size).map { row in
            PicrossPuzzle.clue(for: (0..<size).map { solution[row * size + $0] })
        }
    }

    var columnClues: [[Int]] {
        (0..<size).map { column in
            PicrossPuzzle.clue(for: (0..<size).map { solution[$0 * size + column] })
        }
    }

    /// Run lengths of filled cells, or [0] for an empty line.
    static func clue(for line: [Bool]) -> [Int] {
        var runs: [Int] = []
        var current = 0
        for filled in line {
            if filled {
                current += 1
            } else if current > 0 {
                runs.append(current)
                current = 0
            }
        }
        if current > 0 { runs.append(current) }
        return runs.isEmpty ? [0] : runs
    }
}

enum PicrossCell: String, Codable, Hashable {
    case empty
    case filled
    /// Marked as "not filled" by the player. Purely a note; ignored when checking.
    case crossed
}

enum PicrossTool: String, Codable, Hashable {
    case fill
    case cross
}

struct PicrossGame: Codable, Hashable {
    let puzzle: PicrossPuzzle
    private(set) var cells: [PicrossCell]

    init(puzzle: PicrossPuzzle) {
        self.puzzle = puzzle
        self.cells = Array(repeating: .empty, count: puzzle.size * puzzle.size)
    }

    var isSolved: Bool {
        zip(cells, puzzle.solution).allSatisfy { cell, shouldFill in
            (cell == .filled) == shouldFill
        }
    }

    var hasProgress: Bool { cells.contains { $0 != .empty } }

    /// Applies the tool to a cell. Using the same tool again clears it.
    mutating func apply(_ tool: PicrossTool, at index: Int) {
        guard cells.indices.contains(index), !isSolved else { return }
        switch (tool, cells[index]) {
        case (.fill, .filled), (.cross, .crossed):
            cells[index] = .empty
        case (.fill, _):
            cells[index] = .filled
        case (.cross, _):
            cells[index] = .crossed
        }
    }

    /// True when a row's filled cells already match its clue.
    func isRowSatisfied(_ row: Int) -> Bool {
        let line = (0..<puzzle.size).map { cells[row * puzzle.size + $0] == .filled }
        return PicrossPuzzle.clue(for: line) == puzzle.rowClues[row]
    }

    func isColumnSatisfied(_ column: Int) -> Bool {
        let line = (0..<puzzle.size).map { cells[$0 * puzzle.size + column] == .filled }
        return PicrossPuzzle.clue(for: line) == puzzle.columnClues[column]
    }
}

/// Brute-force line solver used by tests to prove uniqueness of small puzzles.
enum PicrossSolver {
    static func countSolutions(rowClues: [[Int]], columnClues: [[Int]], size: Int, limit: Int = 2) -> Int {
        let allLines: [[Bool]] = (0..<(1 << size)).map { mask in
            (0..<size).map { mask & (1 << (size - 1 - $0)) != 0 }
        }
        let options = rowClues.map { clue in allLines.filter { PicrossPuzzle.clue(for: $0) == clue } }
        var count = 0
        var chosen: [[Bool]] = []

        func search(_ row: Int) {
            if count >= limit { return }
            if row == size {
                let valid = (0..<size).allSatisfy { column in
                    PicrossPuzzle.clue(for: chosen.map { $0[column] }) == columnClues[column]
                }
                if valid { count += 1 }
                return
            }
            for line in options[row] {
                chosen.append(line)
                search(row + 1)
                chosen.removeLast()
            }
        }

        search(0)
        return count
    }
}
