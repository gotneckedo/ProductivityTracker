import Foundation

/// Boundary for puzzle content. V1 bundles one of each; a generator or a
/// daily-puzzle provider can conform later without touching the views.
protocol PuzzleProviding {
    func sudoku(for date: Date) -> SudokuPuzzle
    func picross(for date: Date) -> PicrossPuzzle
    func wordSearch(for date: Date) -> WordSearchPuzzle
}

/// Hand-checked bundled puzzles. Uniqueness is verified in `PuzzleTests`.
struct BundledPuzzleLibrary: PuzzleProviding {
    static let sudoku6 = SudokuPuzzle(
        id: "sudoku-6x6-001",
        size: 6,
        boxRows: 2,
        boxColumns: 3,
        givens: "..624....6....415.....242.54.31...62",
        solution: "536241412635324156651324265413143562"
    )

    static let sprout = PicrossPuzzle(
        id: "picross-5x5-sprout",
        title: "Sprout",
        rows: [
            ".#.#.",
            "..#..",
            "..#..",
            "#####",
            ".###."
        ]
    )

    static let quietWords = WordSearchPuzzle(
        id: "wordsearch-7x7-quiet",
        size: 7,
        rows: [
            "WKTRBWC",
            "MTWALKL",
            "ROUIACE",
            "YKSNMNA",
            "HTUSPKF",
            "BECVCRC",
            "KARPAGE"
        ],
        words: ["LEAF", "RAIN", "MOSS", "TEA", "LAMP", "PAGE"]
    )

    func sudoku(for date: Date) -> SudokuPuzzle { Self.sudoku6 }
    func picross(for date: Date) -> PicrossPuzzle { Self.sprout }
    func wordSearch(for date: Date) -> WordSearchPuzzle { Self.quietWords }
}
