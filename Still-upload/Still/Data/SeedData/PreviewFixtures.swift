import Foundation

/// Deterministic sample data for SwiftUI previews and tests.
enum PreviewFixtures {
    /// Adds completed sessions across recent days, a few tasks, and activity
    /// usage, all timestamped relative to `clock.now`.
    static func populate(_ container: DependencyContainer, completedSessions: Int = 9) {
        let calendar = container.calendar
        let now = container.clock.now
        let engine = FocusTimerEngine()

        container.preferences.completeOnboarding(goal: .focusBetter)

        let biology = TaskItem(title: "Biology homework", createdAt: now.addingTimeInterval(-3 * 3600))
        let essay = TaskItem(title: "Outline the essay", createdAt: now.addingTimeInterval(-2 * 3600))
        let inbox = TaskItem(title: "Reply to Sam", createdAt: now.addingTimeInterval(-26 * 3600),
                             completedAt: now.addingTimeInterval(-3600))
        [biology, essay, inbox].forEach { try? container.tasks.save($0) }

        let dayOffsets = [0, 0, 1, 2, 2, 3, 5, 6, 8, 9, 10, 12]
        for index in 0..<min(completedSessions, dayOffsets.count) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffsets[index], to: now) else { continue }
            let start = day.addingTimeInterval(-Double(30 + index * 5) * 60)
            let minutes = [25.0, 25, 50, 25, 30, 25, 45, 25, 25, 20, 25, 25][index]
            var configuration = TimerConfiguration.standard
            configuration.focusDuration = minutes * 60
            var session = engine.makeSession(
                id: UUID(),
                configuration: configuration,
                taskID: index == 0 ? biology.id : nil,
                sceneID: .rainyBedroom,
                renderMode: .scene,
                presetID: .defaultPreset,
                source: .manual,
                at: start
            )
            session = engine.advance(session, to: start.addingTimeInterval(minutes * 60 + 1)).0
            try? container.sessions.save(session)
        }

        let usageSpecs: [(BreakActivityID, ActivityOutcome, Double)] = [
            (.boxBreathing, .completed, 1), (.sudoku, .completed, 20), (.shortRead, .completed, 26),
            (.boxBreathing, .completed, 50), (.brainDump, .abandoned, 80)
        ]
        for (id, outcome, hoursAgo) in usageSpecs {
            let start = now.addingTimeInterval(-hoursAgo * 3600)
            try? container.usages.save(ActivityUsage(
                id: UUID(), activityID: id, startedAt: start,
                endedAt: start.addingTimeInterval(180), outcome: outcome, context: .shelf
            ))
        }
    }

    /// Starts a running session for "active session" previews.
    static func startSession(_ container: DependencyContainer, elapsed: TimeInterval = 7 * 60) {
        let task = container.taskController.create(title: "Biology homework")
        container.focus.start(presetID: .defaultPreset, taskID: task?.id, source: .manual)
        if let manual = container.clock as? ManualClock {
            manual.advance(by: elapsed)
            container.focus.tick()
        }
    }
}
