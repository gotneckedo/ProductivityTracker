import Foundation

/// Builds fully in-memory app states for SwiftUI previews.
enum PreviewSupport {
    static func appState(
        onboarded: Bool = true,
        goal: OnboardingGoal = .focusBetter,
        populated: Bool = false,
        completedSessions: Int = 9,
        renderMode: RenderMode? = nil,
        activeSession: Bool = false,
        activeSessionElapsed: TimeInterval = 7 * 60,
        clockStart: Date? = nil
    ) -> AppState {
        let clock = ManualClock(clockStart ?? Date())
        let bundledBooks = BundledBookLocator.urls(in: Bundle(for: AppState.self))
        let bookLibrary = FileBookLibrary(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent("StillPreviewBooks", isDirectory: true),
            bundledURLs: bundledBooks,
            clock: clock
        )
        let container = DependencyContainer.inMemory(
            clock: clock,
            flags: .preview,
            audio: SilentAmbientAudioPlayer(status: .ready, availableSources: Set(AmbientSource.all.map(\.id))),
            bookLibrary: bookLibrary
        )
        if populated {
            PreviewFixtures.populate(container, completedSessions: completedSessions)
            PreviewFixtures.populateDailyLife(container)
        } else if onboarded {
            container.preferences.completeOnboarding(goal: goal)
        }
        if let renderMode {
            var preset = container.preferences.preset(.defaultPreset)
            preset.renderMode = renderMode
            container.preferences.save(preset)
        }
        if activeSession {
            PreviewFixtures.startSession(container, elapsed: activeSessionElapsed)
            if let task = container.tasks.allTasks().last {
                container.preferences.update { $0.selectedTaskID = task.id }
            }
        }
        return AppState(container: container)
    }

    /// A state whose session just completed, plus that session's ID.
    static func completedSession() -> (state: AppState, sessionID: UUID) {
        let clock = ManualClock(Date())
        let container = DependencyContainer.inMemory(clock: clock, flags: .preview)
        container.preferences.completeOnboarding(goal: .scrollLess)
        let task = container.taskController.create(title: "Biology homework")
        container.preferences.update { $0.selectedTaskID = task?.id }
        let session = container.focus.start(presetID: .defaultPreset, taskID: task?.id, source: .manual).session
        clock.advance(by: 25 * 60)
        container.focus.tick()
        return (AppState(container: container), session.id)
    }
}
