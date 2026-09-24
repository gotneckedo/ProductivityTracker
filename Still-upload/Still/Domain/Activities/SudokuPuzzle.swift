import Foundation

/// A small Sudoku with rectangular boxes (6×6 uses 2×3 boxes).
/// Puzzle data is separate from game state so a generator or daily puzzle
/// can replace the bundled one later.
struct SudokuPuzzle: Codable, Hashable, Identifiable {
    let id: String
    let size: Int
    let boxRows: Int
    let boxColumns: Int
    /// Row-major givens; 0 means empty.
    let givens: [Int]
    /// Row-major solution.
    let solution: [Int]

    /// Parses row-major strings where `.` or `0` marks an empty cell.
    init(id: String, size: Int, boxRows: Int, boxColumns: Int, givens: String, solution: String) {
        self.id = id
        self.size = size
        self.boxRows = boxRows
        self.boxColumns = boxColumns
        self.givens = givens.map { Int(String($0)) ?? 0 }
        self.solution = solution.map { Int(String($0)) ?? 0 }
    }

    var cellCount: Int { size * size }

    func isGiven(_ index: Int) -> Bool { givens[index] != 0 }

    func row(of index: Int) -> Int { index / size }
    func column(of index: Int) -> Int { index % size }
    func box(of index: Int) -> Int {
        (row(of: index) / boxRows) * (size / boxColumns) + column(of: index) / boxColumns
    }

    /// Indices sharing a row, column, or box with `index` (excluding itself).
    func peers(of index: Int) -> [Int] {
        (0..<cellCount).filter { other in
            other != index && (row(of: other) == row(of: index)
                || column(of: other) == column(of: index)
                || box(of: other) == box(of: index))
        }
    }
}

struct SudokuGame: Codable, Hashable {
    let puzzle: SudokuPuzzle
    /// Row-major values including givens; 0 means empty.
    private(set) var values: [Int]
    var selectedIndex: Int?

    init(puzzle: SudokuPuzzle) {
        self.puzzle = puzzle
        self.values = puzzle.givens
        self.selectedIndex = nil
    }

    var isSolved: Bool { values == puzzle.solution }

    var filledCount: Int { values.filter { $0 != 0 }.count }

    var hasProgress: Bool { values != puzzle.givens }

    mutating func select(_ index: Int) {
        guard puzzle.givens.indices.contains(index) else { return }
        selectedIndex = index
    }

    /// Places a number in the selected editable cell. Returns false if ignored.
    @discardableResult
    mutating func enter(_ number: Int) -> Bool {
        guard let index = selectedIndex, !puzzle.isGiven(index), !isSolved,
              (1...puzzle.size).contains(number) else { return false }
        values[index] = number
        return true
    }

    @discardableResult
    mutating func erase() -> Bool {
        guard let index = selectedIndex, !puzzle.isGiven(index), !isSolved, values[index] != 0 else { return false }
        values[index] = 0
        return true
    }

    /// Cells whose value repeats within a row, column, or box.
    /// Used for gentle feedback; wrong-but-legal entries are not flagged.
    var conflictingIndices: Set<Int> {
        var result = Set<Int>()
        for index in values.indices where values[index] != 0 {
            for peer in puzzle.peers(of: index) where values[peer] == values[index] {
                result.insert(index)
            }
        }
        return result
    }

    func value(at index: Int) -> Int? {
        values[index] == 0 ? nil : values[index]
    }

    /// How many of each number are placed; helps dim finished numbers on the pad.
    func placedCount(of number: Int) -> Int {
        values.filter { $0 == number }.count
    }

    /// The number pad only retires a digit after all six instances are present
    /// on this 6×6 board. A fresh puzzle therefore always presents every digit
    /// at full strength.
    func isDigitComplete(_ number: Int) -> Bool {
        placedCount(of: number) >= puzzle.size
    }
}

/// Counts solutions by backtracking, stopping at `limit`. Used by tests to
/// prove bundled puzzles are uniquely solvable.
enum SudokuSolver {
    static func countSolutions(_ puzzle: SudokuPuzzle, limit: Int = 2) -> Int {
        var grid = puzzle.givens
        return count(&grid, puzzle: puzzle, limit: limit)
    }

    private static func count(_ grid: inout [Int], puzzle: SudokuPuzzle, limit: Int) -> Int {
        guard let empty = grid.firstIndex(of: 0) else { return 1 }
        var total = 0
        let peers = puzzle.peers(of: empty)
        for candidate in 1...puzzle.size where !peers.contains(where: { grid[$0] == candidate }) {
            grid[empty] = candidate
            total += count(&grid, puzzle: puzzle, limit: limit)
            grid[empty] = 0
            if total >= limit { return total }
        }
        return total
    }
}
