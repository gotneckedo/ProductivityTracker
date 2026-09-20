import Foundation

/// The finite V1 shelf. Order within a category is `sortOrder`.
enum ActivityCatalog {
    static let all: [BreakActivity] = [
        BreakActivity(id: .sudoku, name: "Sudoku", category: .puzzle,
                      summary: "A small 6×6 grid. Numbers 1 to 6.",
                      estimatedDuration: 6 * 60, implementationState: .available,
                      symbolName: "square.grid.3x3", sortOrder: 0),
        BreakActivity(id: .picross, name: "Picross", category: .puzzle,
                      summary: "Fill a 5×5 picture from its clues.",
                      estimatedDuration: 4 * 60, implementationState: .available,
                      symbolName: "square.grid.2x2", sortOrder: 1),
        BreakActivity(id: .wordSearch, name: "Word Search", category: .puzzle,
                      summary: "Six quiet words hidden in a grid.",
                      estimatedDuration: 4 * 60, implementationState: .available,
                      symbolName: "textformat.abc", sortOrder: 2),
        BreakActivity(id: .shortRead, name: "Short Read", category: .quiet,
                      summary: "A few minutes of reading that ends.",
                      estimatedDuration: 3 * 60, implementationState: .available,
                      symbolName: "book", sortOrder: 0),
        BreakActivity(id: .creativePrompt, name: "Creative Prompt", category: .quiet,
                      summary: "One small prompt, a few lines back.",
                      estimatedDuration: 5 * 60, implementationState: .available,
                      symbolName: "pencil.line", sortOrder: 1),
        BreakActivity(id: .brainDump, name: "Brain Dump", category: .reset,
                      summary: "Empty your head onto the page.",
                      estimatedDuration: 3 * 60, implementationState: .available,
                      symbolName: "text.alignleft", sortOrder: 0),
        BreakActivity(id: .guidedStretch, name: "Guided Stretch", category: .reset,
                      summary: "Four gentle steps at your desk.",
                      estimatedDuration: 2 * 60, implementationState: .available,
                      symbolName: "figure.cooldown", sortOrder: 1),
        BreakActivity(id: .boxBreathing, name: "Box Breathing", category: .reset,
                      summary: "Two minutes of 4–4–4–4 breathing.",
                      estimatedDuration: 2 * 60, implementationState: .available,
                      symbolName: "square", sortOrder: 2),
        BreakActivity(id: .doNothing, name: "Do Nothing", category: .reset,
                      summary: "One quiet minute. That's all.",
                      estimatedDuration: 60, implementationState: .available,
                      symbolName: "circle.dotted", sortOrder: 3)
    ]

    static var available: [BreakActivity] {
        all.filter { $0.implementationState == .available }
    }

    static func activity(_ id: BreakActivityID) -> BreakActivity? {
        all.first { $0.id == id }
    }

    static func grouped() -> [(category: ActivityCategory, activities: [BreakActivity])] {
        ActivityCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { category in
                (category, available.filter { $0.category == category }.sorted { $0.sortOrder < $1.sortOrder })
            }
            .filter { !$0.activities.isEmpty }
    }
}
