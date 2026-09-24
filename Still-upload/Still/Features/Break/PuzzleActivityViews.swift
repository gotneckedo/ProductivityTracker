import SwiftUI

// Small, calm puzzle modules. Puzzle rules live in the domain models
// (`SudokuGame`, `PicrossGame`, `WordSearchGame`); these views only draw them
// and save progress after every move.

// MARK: - Sudoku

struct SudokuActivityView: View {
    let onSolved: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.stillDayPhase) private var phase
    @Environment(\.colorScheme) private var colorScheme
    @State private var game: SudokuGame?
    @State private var history = SudokuMoveHistory()

    private var resolvedPhase: StillDayPhase {
        phase ?? StillDayPhase.automatic(colorScheme: colorScheme)
    }

    private var style: ActivityVisualStyle {
        ActivityPresentation.visualStyle(for: .sudoku)
    }

    var body: some View {
        ActivityGlassCard(activityID: .sudoku) {
            VStack(spacing: StillTheme.Spacing.l) {
                if let game {
                    Text(game.isSolved ? "Solved. Every row, column, and box holds 1 to 6." : "Fill each row, column, and box with 1 to 6.")
                        .font(StillTypography.callout)
                        .foregroundStyle(StillTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    grid(game)
                    if game.isSolved {
                        Button("Start over") { reset() }
                            .buttonStyle(QuietSecondaryButtonStyle())
                    } else {
                        numberPad(game)
                        controlRow(game)
                        feedback(game)
                    }
                }
            }
        }
        .onAppear(perform: load)
    }

    private func grid(_ game: SudokuGame) -> some View {
        let puzzle = game.puzzle
        let conflicts = game.conflictingIndices
        return VStack(spacing: 10) {
            ForEach(0..<(puzzle.size / puzzle.boxRows), id: \.self) { boxRow in
                HStack(spacing: 10) {
                    ForEach(0..<(puzzle.size / puzzle.boxColumns), id: \.self) { boxColumn in
                        VStack(spacing: 3) {
                            ForEach(0..<puzzle.boxRows, id: \.self) { rowOffset in
                                HStack(spacing: 3) {
                                    ForEach(0..<puzzle.boxColumns, id: \.self) { columnOffset in
                                        let row = boxRow * puzzle.boxRows + rowOffset
                                        let column = boxColumn * puzzle.boxColumns + columnOffset
                                        let index = row * puzzle.size + column
                                        cell(game: game, index: index, isConflict: conflicts.contains(index))
                                    }
                                }
                            }
                        }
                        .padding(3)
                        .background(resolvedPhase.glassFill.opacity(0.34), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(resolvedPhase.glassBorder.opacity(0.72), lineWidth: StillTheme.Stroke.hairline))
                    }
                }
            }
        }
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity)
    }

    private func cell(game: SudokuGame, index: Int, isConflict: Bool) -> some View {
        let isGiven = game.puzzle.isGiven(index)
        let emphasis = game.emphasis(at: index)
        let isSelected = emphasis == .selected
        let value = game.value(at: index)
        let palette = style.accentColor(for: resolvedPhase)
        let fill: Color
        switch emphasis {
        case .selected: fill = palette.opacity(0.28)
        case .conflict: fill = StillTheme.attentionSoft
        case .matchingNumber: fill = palette.opacity(0.20)
        case .peer: fill = resolvedPhase.glassFill.opacity(0.76)
        case .none: fill = isGiven ? resolvedPhase.glassFill.opacity(0.58) : resolvedPhase.glassFill.opacity(0.35)
        }
        return Button {
            update { $0.select(index) }
        } label: {
            // Same structure as the Picross cell: a flexible shape sized square
            // by aspectRatio, with the digit on top. (Sizing the Text itself
            // collapsed the cells to its line height.)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill)
                // Box-level outlines already define the six 2×3 groups. Only
                // a selected or conflicting cell earns an inner outline, so
                // adjacent cells never read as a heavy double grid.
                if isSelected || isConflict {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isConflict ? StillTheme.attention : StillTheme.accent,
                                      lineWidth: isSelected ? 2 : StillTheme.Stroke.hairline)
                }
                Text(value.map { String($0) } ?? "")
                    .font(StillTypography.title3.weight(isGiven ? .semibold : .regular))
                    .foregroundStyle(isConflict ? StillTheme.attention : isGiven ? resolvedPhase.ink : palette)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Row \(game.puzzle.row(of: index) + 1), column \(game.puzzle.column(of: index) + 1)")
        .accessibilityValue(value.map { "\($0)\(isGiven ? ", given" : "")" } ?? "Empty")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func numberPad(_ game: SudokuGame) -> some View {
        HStack(spacing: StillTheme.Spacing.xs) {
            ForEach(1...game.puzzle.size, id: \.self) { number in
                let isUsed = game.isDigitComplete(number)
                Button {
                    update(recordingMove: true) { _ = $0.enter(number) }
                } label: {
                    Text("\(number)")
                        .font(StillTypography.title3.weight(.semibold))
                        .foregroundStyle(isUsed ? StillTheme.textTertiary : resolvedPhase.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        // Backgrounds sit behind the digit. The prior overlay
                        // order painted glass over every label, making a fresh
                        // keypad look disabled before any six-count was met.
                        .background(Capsule(style: .continuous).fill(resolvedPhase.glassFill))
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).strokeBorder(resolvedPhase.glassBorder, lineWidth: StillTheme.Stroke.hairline))
                        .opacity(isUsed ? 0.32 : 1)
                }
                .buttonStyle(.plain)
                // A digit is only retired after all six occurrences exist.
                // Selection is not a visual completion state, so unselected
                // digits retain their normal contrast from the start.
                .disabled(isUsed)
                .accessibilityLabel("Enter \(number)")
                .accessibilityValue(isUsed ? "All placed" : "")
            }
        }
    }

    private func controlRow(_ game: SudokuGame) -> some View {
        HStack(spacing: StillTheme.Spacing.xs) {
            Button(action: undo) {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(QuietSecondaryButtonStyle())
            .disabled(!history.canUndo)
            .accessibilityHint("Restores the previous number or erase action.")

            Button {
                update(recordingMove: true) { _ = $0.erase() }
            } label: {
                Label("Erase", systemImage: "delete.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(QuietSecondaryButtonStyle())
            .disabled(game.selectedIndex == nil || game.selectedIndex.map(game.puzzle.isGiven) == true)
        }
    }

    @ViewBuilder
    private func feedback(_ game: SudokuGame) -> some View {
        if !game.conflictingIndices.isEmpty {
            QuietNote(text: "Two of the same number share a row, column, or box.", symbol: "circle.lefthalf.filled")
        } else if game.selectedIndex == nil {
            QuietNote(text: "Tap an empty square, then a number.")
        }
    }

    private func load() {
        guard game == nil else { return }
        let puzzle = appState.container.puzzles.sudoku(for: Date())
        game = appState.container.puzzleProgress.load(SudokuGame.self, puzzleID: puzzle.id) ?? SudokuGame(puzzle: puzzle)
    }

    private func reset() {
        guard let puzzle = game?.puzzle else { return }
        try? appState.container.puzzleProgress.clear(puzzleID: puzzle.id)
        game = SudokuGame(puzzle: puzzle)
        history.clear()
    }

    private func update(recordingMove: Bool = false, _ change: (inout SudokuGame) -> Void) {
        guard var current = game else { return }
        let previous = current
        let wasSolved = current.isSolved
        change(&current)
        if recordingMove && current != previous { history.record(previous) }
        game = current
        try? appState.container.puzzleProgress.save(current, puzzleID: current.puzzle.id, at: Date())
        if current.isSolved && !wasSolved { onSolved() }
    }

    private func undo() {
        guard var current = game, history.undo(current: &current) else { return }
        game = current
        try? appState.container.puzzleProgress.save(current, puzzleID: current.puzzle.id, at: Date())
    }
}

// MARK: - Picross

struct PicrossActivityView: View {
    let onSolved: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.stillDayPhase) private var phase
    @Environment(\.colorScheme) private var colorScheme
    @State private var game: PicrossGame?
    @State private var tool: PicrossTool = .fill

    private var resolvedPhase: StillDayPhase {
        phase ?? StillDayPhase.automatic(colorScheme: colorScheme)
    }

    /// CI renders this at the available width of a 320-point content region,
    /// making the narrow-phone layout a visual regression target without
    /// changing the production board width on larger phones.
    private var narrowProofWidth: CGFloat? {
        #if DEBUG
        return DemoLaunch.requestedScreen == "picross-320" ? 280 : nil
        #else
        return nil
        #endif
    }

    var body: some View {
        VStack(spacing: StillTheme.Spacing.l) {
            if let game {
                Text(game.isSolved ? "Solved: \(game.puzzle.title)." : "Fill squares so each row and column matches its numbers.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !game.isSolved {
                    SelectionPill(options: [PicrossTool.fill, PicrossTool.cross], selection: $tool) { option in
                        option == .fill ? "Fill" : "Mark empty"
                    }
                }
                board(game)
                    .frame(maxWidth: narrowProofWidth)
                    .frame(maxWidth: .infinity)
                if game.isSolved {
                    Button("Start over") { reset() }
                        .buttonStyle(QuietSecondaryButtonStyle())
                }
            }
        }
        .onAppear(perform: load)
    }

    private func board(_ game: PicrossGame) -> some View {
        let size = game.puzzle.size
        let columnClues = game.puzzle.columnClues
        let rowClues = game.puzzle.rowClues
        return GeometryReader { proxy in
            // The clue column and every board cell derive from the actual
            // available width. On a 320-point iPhone this produces roughly
            // 45-point cells, so the puzzle remains fully visible without
            // horizontal scrolling or clipped clue labels.
            let clueWidth = min(52, max(38, proxy.size.width * 0.18))
            let cellWidth = max(1, (proxy.size.width - clueWidth - 4 * CGFloat(size)) / CGFloat(size))
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 4) {
                    Color.clear.frame(width: clueWidth, height: 40)
                    ForEach(0..<size, id: \.self) { column in
                        VStack(spacing: 0) {
                            ForEach(Array(columnClues[column].enumerated()), id: \.offset) { item in
                                Text("\(item.element)")
                            }
                        }
                        .font(StillTypography.footnote.monospacedDigit())
                        .foregroundStyle(game.isColumnSatisfied(column) ? StillTheme.textTertiary : StillTheme.textPrimary)
                        .frame(width: cellWidth, height: 40, alignment: .bottom)
                        .accessibilityLabel("Column \(column + 1) clue \(columnClues[column].map { String($0) }.joined(separator: " "))")
                    }
                }

                ForEach(0..<size, id: \.self) { row in
                    HStack(spacing: 4) {
                        Text(rowClues[row].map { String($0) }.joined(separator: " "))
                            .font(StillTypography.footnote.monospacedDigit())
                            .foregroundStyle(game.isRowSatisfied(row) ? StillTheme.textTertiary : StillTheme.textPrimary)
                            .frame(width: clueWidth, height: cellWidth, alignment: .trailing)
                            .accessibilityLabel("Row \(row + 1) clue \(rowClues[row].map { String($0) }.joined(separator: " "))")
                        ForEach(0..<size, id: \.self) { column in
                            cell(game: game, index: row * size + column, row: row, column: column)
                                .frame(width: cellWidth, height: cellWidth)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .aspectRatio(1.02, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func cell(game: PicrossGame, index: Int, row: Int, column: Int) -> some View {
        let state = game.cells[index]
        let filledColor = game.isSolved ? StillTheme.accent : StillTheme.textPrimary
        return Button {
            update { $0.apply(tool, at: index) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(state == .filled ? filledColor : resolvedPhase.glassFill.opacity(0.45))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(resolvedPhase.glassBorder.opacity(0.42), lineWidth: StillTheme.Stroke.hairline)
                if state == .crossed {
                    Image(systemName: "xmark")
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textTertiary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(game.isSolved)
        .accessibilityLabel("Row \(row + 1), column \(column + 1)")
        .accessibilityValue(state == .filled ? "Filled" : state == .crossed ? "Marked empty" : "Blank")
    }

    private func load() {
        guard game == nil else { return }
        let puzzle = appState.container.puzzles.picross(for: Date())
        game = appState.container.puzzleProgress.load(PicrossGame.self, puzzleID: puzzle.id) ?? PicrossGame(puzzle: puzzle)
    }

    private func reset() {
        guard let puzzle = game?.puzzle else { return }
        try? appState.container.puzzleProgress.clear(puzzleID: puzzle.id)
        game = PicrossGame(puzzle: puzzle)
    }

    private func update(_ change: (inout PicrossGame) -> Void) {
        guard var current = game else { return }
        let wasSolved = current.isSolved
        change(&current)
        game = current
        try? appState.container.puzzleProgress.save(current, puzzleID: current.puzzle.id, at: Date())
        if current.isSolved && !wasSolved { onSolved() }
    }
}

// MARK: - Word Search

struct WordSearchActivityView: View {
    let onSolved: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.stillDayPhase) private var phase
    @Environment(\.colorScheme) private var colorScheme
    @State private var game: WordSearchGame?
    @State private var message = "Tap the first letter of a word, then its last letter."

    private var resolvedPhase: StillDayPhase {
        phase ?? StillDayPhase.automatic(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
            if let game {
                Text(game.isSolved ? "All six found." : message)
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                grid(game)
                wordList(game)
                if game.isSolved {
                    Button("Start over") { reset() }
                        .buttonStyle(QuietSecondaryButtonStyle())
                }
            }
        }
        .onAppear(perform: load)
    }

    private func grid(_ game: WordSearchGame) -> some View {
        let puzzle = game.puzzle
        return VStack(spacing: 4) {
            ForEach(0..<puzzle.size, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<puzzle.size, id: \.self) { column in
                        letterCell(game: game, point: GridPoint(row: row, column: column))
                    }
                }
            }
        }
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity)
    }

    private func letterCell(game: WordSearchGame, point: GridPoint) -> some View {
        let letter = game.puzzle.letter(at: point).map { String($0) } ?? ""
        let isFound = game.foundCells.contains(point)
        let isPending = game.pendingStart == point
        let fill: Color = isPending ? StillTheme.highlightSoft : isFound ? StillTheme.accentSoft : resolvedPhase.glassFill.opacity(0.45)
        return Button {
            tap(point)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isPending ? StillTheme.highlight : resolvedPhase.glassBorder.opacity(0.42),
                                  lineWidth: isPending ? 2 : StillTheme.Stroke.hairline)
                Text(letter)
                    .font(StillTypography.headline)
                    .foregroundStyle(StillTheme.textPrimary)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(game.isSolved)
        .accessibilityLabel("\(letter), row \(point.row + 1), column \(point.column + 1)")
        .accessibilityValue(isPending ? "Selection started" : isFound ? "Part of a found word" : "")
    }

    private func wordList(_ game: WordSearchGame) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: StillTheme.Spacing.xs)], alignment: .leading, spacing: StillTheme.Spacing.xs) {
            ForEach(game.puzzle.words, id: \.self) { word in
                let found = game.foundWords.contains(word)
                Text(word.capitalized)
                    .font(StillTypography.callout)
                    .strikethrough(found, color: StillTheme.textTertiary)
                    .foregroundStyle(found ? StillTheme.textTertiary : StillTheme.textPrimary)
                    .padding(.horizontal, StillTheme.Spacing.s)
                    .padding(.vertical, StillTheme.Spacing.xxs)
                    .background(Capsule(style: .continuous).fill(found ? StillTheme.accentSoft : StillTheme.surfaceSunken))
                    .accessibilityValue(found ? "Found" : "Not found yet")
            }
        }
    }

    private func tap(_ point: GridPoint) {
        guard var current = game else { return }
        let wasSolved = current.isSolved
        let result = current.tap(point)
        game = current
        switch result {
        case .startedSelection:
            message = "Now tap the word's last letter."
        case .cleared:
            message = "Selection cleared."
        case .found(let word):
            message = "Found \(word.capitalized)."
        case .noMatch:
            message = "Not a word from the list. Try another pair."
        }
        try? appState.container.puzzleProgress.save(current, puzzleID: current.puzzle.id, at: Date())
        if current.isSolved && !wasSolved { onSolved() }
    }

    private func load() {
        guard game == nil else { return }
        let puzzle = appState.container.puzzles.wordSearch(for: Date())
        game = appState.container.puzzleProgress.load(WordSearchGame.self, puzzleID: puzzle.id) ?? WordSearchGame(puzzle: puzzle)
    }

    private func reset() {
        guard let puzzle = game?.puzzle else { return }
        try? appState.container.puzzleProgress.clear(puzzleID: puzzle.id)
        game = WordSearchGame(puzzle: puzzle)
        message = "Tap the first letter of a word, then its last letter."
    }
}

#Preview("Sudoku · unfinished") {
    ActivityContainerView(activityID: .sudoku, context: .shelf)
        .environment(PreviewSupport.appState())
}

#Preview("Picross · finished") {
    let state = PreviewSupport.appState()
    var solved = PicrossGame(puzzle: BundledPuzzleLibrary.sprout)
    for index in solved.puzzle.solution.indices where solved.puzzle.solution[index] {
        solved.apply(.fill, at: index)
    }
    try? state.container.puzzleProgress.save(solved, puzzleID: solved.puzzle.id, at: Date())
    return ActivityContainerView(activityID: .picross, context: .shelf)
        .environment(state)
}
