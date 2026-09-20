import Foundation

/// Builds fully in-memory app states for SwiftUI previews.
enum PreviewSupport {
    static func appState(
        onboarded: Bool = true,
        goal: OnboardingGoal = .focusBetter,
        populated: Bool = false,
        renderMode: RenderMode? = nil,
        activeSession: Bool = false
    ) -> AppState {
        let container = DependencyContainer.inMemory(
            clock: ManualClock(Date()),
            audio: SilentAmbientAudioPlayer(status: .ready, availableSources: Set(AmbientSource.all.map(\.id)))
        )
        if populated {
            PreviewFixtures.populate(container)
        } else if onboarded {
            container.preferences.completeOnboarding(goal: goal)
        }
        if let renderMode {
            var preset = container.preferences.preset(.defaultPreset)
            preset.renderMode = renderMode
            container.preferences.save(preset)
        }
        if activeSession {
            PreviewFixtures.startSession(container)
            if let task = container.tasks.allTasks().last {
                container.preferences.update { $0.selectedTaskID = task.id }
            }
        }
        return AppState(container: container)
    }

    /// A state whose session just completed, plus that session's ID.
    static func completedSession() -> (state: AppState, sessionID: UUID) {
        let clock = ManualClock(Date())
        let container = DependencyContainer.inMemory(clock: clock)
        container.preferences.completeOnboarding(goal: .scrollLess)
        let task = container.taskController.create(title: "Biology homework")
        container.preferences.update { $0.selectedTaskID = task?.id }
        let session = container.focus.start(presetID: .defaultPreset, taskID: task?.id, source: .manual).session
        clock.advance(by: 25 * 60)
        container.focus.tick()
        return (AppState(container: container), session.id)
    }
}
