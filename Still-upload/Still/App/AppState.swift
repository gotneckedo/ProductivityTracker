import Foundation
import Observation

/// A short, calm message shown at the top of the app (never an alert).
struct StillNotice: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// The observable app store. It holds mirrored, display-ready state and
/// forwards every action to the platform-neutral controllers in
/// `DependencyContainer`, then reloads. Business rules live in the controllers
/// and engines (all unit-tested), not here and not in views.
@Observable
final class AppState {
    let container: DependencyContainer
    let router: AppRouter

    private(set) var preferences: UserPreferences
    private(set) var presets: [FocusPreset] = []
    private(set) var activeSession: FocusSession? = nil
    private(set) var snapshot: TimerSnapshot? = nil
    private(set) var todaysTasks: [TaskItem] = []
    private(set) var sessions: [FocusSession] = []
    private(set) var usages: [ActivityUsage] = []
    private(set) var stats: FocusStats = .empty
    /// Mute toggled on the active screen. Transient: the preset mix is unchanged.
    private(set) var isAudioMuted = false
    var notice: StillNotice? = nil

    /// Suggestions are generated once per completed session so they don't
    /// shuffle while the user looks at them.
    @ObservationIgnored private var suggestionCache: [UUID: BreakSuggestionSet] = [:]
    @ObservationIgnored private var hasBootstrapped = false

    init(container: DependencyContainer) {
        self.container = container
        self.router = AppRouter(flags: container.flags)
        self.preferences = container.preferencesStore.load()
        let reportError: (Error) -> Void = { [weak self] _ in
            self?.notice = StillNotice(text: "Couldn't save that change. Your session is still running.")
        }
        container.focus.onPersistenceError = reportError
        container.breaks.onPersistenceError = reportError
        container.taskController.onPersistenceError = reportError
        container.preferences.onPersistenceError = reportError
        if let storageNotice = container.storageNotice {
            notice = StillNotice(text: storageNotice)
        }
        reload()
    }

    // MARK: - Lifecycle

    /// Called once at launch: restores a running session, closes activity
    /// usages left open by a force-quit, and reopens a pending completion.
    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        container.breaks.closeStaleUsages()
        let events = container.focus.restore()
        reload()
        handle(events)
        if let pending = preferences.pendingCompletionSessionID, router.completion == nil {
            if sessions.contains(where: { $0.id == pending && $0.state == .completed }) {
                router.go(to: .sessionComplete(pending))
            } else {
                container.focus.acknowledgeCompletion(returningToFocus: false)
                reload()
            }
        }
    }

    /// Call when the app returns to the foreground.
    func handleBecameActive() {
        tick()
        reload()
    }

    /// Advances the running session. The active screen calls this each second.
    func tick() {
        let events = container.focus.tick()
        snapshot = container.focus.snapshot()
        if !events.isEmpty {
            reload()
            handle(events)
        }
    }

    func reload() {
        preferences = container.preferencesStore.load()
        presets = container.presets.allPresets()
        activeSession = container.focus.activeSession
        snapshot = container.focus.snapshot()
        todaysTasks = container.taskController.todaysTasks()
        sessions = container.sessions.allSessions()
        usages = container.usages.allUsages()
        stats = StatsCalculator(calendar: container.calendar)
            .stats(sessions: sessions, usages: usages, now: container.clock.now)
    }

    private func handle(_ events: [FocusFlowEvent]) {
        for event in events {
            if case .sessionCompleted(let id) = event {
                isAudioMuted = false
                router.go(to: .sessionComplete(id))
            }
            if case .sessionAbandoned = event {
                isAudioMuted = false
            }
        }
    }

    // MARK: - Derived

    var personalization: Personalization { Personalization(goal: preferences.onboardingGoal) }

    var currentPreset: FocusPreset {
        presets.first { $0.id == preferences.defaultPresetID }
            ?? presets.first
            ?? PresetCatalog.defaultPreset(personalization: personalization)
    }

    var selectedTask: TaskItem? {
        guard let id = preferences.selectedTaskID else { return nil }
        return todaysTasks.first { $0.id == id && !$0.isCompleted }
    }

    var completedSessionCount: Int { stats.completedSessions }

    var animationIntensity: AnimationIntensity { preferences.animationIntensity }

    func scene(_ id: SceneID) -> SceneDefinition { SceneCatalog.scene(id) }

    func isUnlocked(_ scene: SceneDefinition) -> Bool {
        ProgressionEvaluator().isUnlocked(scene, completedSessions: completedSessionCount)
    }

    var nextLockedScene: (scene: SceneDefinition, remaining: Int)? {
        ProgressionEvaluator().nextLockedScene(in: SceneCatalog.all, completedSessions: completedSessionCount)
    }

    /// Scenes unlocked since the user last looked at the collection.
    var newlyUnlockedScenes: [SceneDefinition] {
        let unlocked = ProgressionEvaluator().unlockedScenes(in: SceneCatalog.all, completedSessions: completedSessionCount)
        return Array(unlocked.dropFirst(min(preferences.acknowledgedUnlockedSceneCount, unlocked.count)))
    }

    func acknowledgeUnlockedScenes() {
        let count = ProgressionEvaluator().unlockedScenes(in: SceneCatalog.all, completedSessions: completedSessionCount).count
        guard count != preferences.acknowledgedUnlockedSceneCount else { return }
        container.preferences.update { $0.acknowledgedUnlockedSceneCount = count }
        reload()
    }

    var audioStatus: AmbientAudioStatus { container.audio.status }

    func session(_ id: UUID) -> FocusSession? {
        sessions.first { $0.id == id } ?? container.sessions.session(id: id)
    }

    func task(_ id: UUID?) -> TaskItem? {
        guard let id else { return nil }
        return container.tasks.task(id: id)
    }

    func usedToday(_ id: BreakActivityID) -> Bool {
        usages.contains { $0.activityID == id && container.calendar.isDate($0.startedAt, inSameDayAs: container.clock.now) }
    }

    // MARK: - Focus

    func startFocus(presetID: FocusPresetID? = nil, source: SessionSource = .manual) {
        let outcome = container.focus.start(
            presetID: presetID ?? preferences.defaultPresetID,
            taskID: preferences.selectedTaskID,
            source: source
        )
        isAudioMuted = false
        switch outcome {
        case .started, .startedWithFallback:
            if case .startedWithFallback = outcome {
                notice = StillNotice(text: "That preset isn't on this phone, so your default session started.")
            }
            router.go(to: .focusHome)
            // Ask for notification permission in context, the first time only.
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.container.focus.requestNotificationPermissionIfNeeded()
                self.reload()
            }
        case .alreadyRunning:
            notice = StillNotice(text: "A session is already running. It's still going.")
            router.go(to: .focusHome)
        }
        reload()
    }

    func pause() {
        container.focus.pause()
        reload()
    }

    func resume() {
        container.focus.resume()
        if isAudioMuted { container.focus.applyMixToRunningSession(.silent) }
        reload()
    }

    func startNextPhase() {
        handle(container.focus.startNextPhase())
        reload()
    }

    func skipBreak() {
        handle(container.focus.skipBreak())
        reload()
    }

    func finishCountUp() {
        let event = container.focus.finishCountUp()
        reload()
        if let event { handle([event]) }
        if case .some(.sessionAbandoned) = event {
            notice = StillNotice(text: "Sessions under 5 minutes aren't counted. That's fine.")
        }
    }

    func endSessionEarly() {
        container.focus.endEarly()
        isAudioMuted = false
        reload()
    }

    func toggleMute() {
        guard let session = activeSession else { return }
        isAudioMuted.toggle()
        let presetMix = presets.first { $0.id == session.presetID }?.ambientMix ?? .silent
        container.focus.applyMixToRunningSession(isAudioMuted ? .silent : presetMix)
    }

    // MARK: - Completion moment

    func suggestions(for sessionID: UUID) -> BreakSuggestionSet {
        if let cached = suggestionCache[sessionID] { return cached }
        let result = container.breaks.suggestions(
            after: session(sessionID),
            personalization: personalization,
            trackPresentation: true
        )
        suggestionCache[sessionID] = result
        return result
    }

    func openSuggestion(_ activity: BreakActivity, rank: Int, sessionID: UUID) {
        container.focus.acknowledgeCompletion(returningToFocus: false)
        reload()
        router.go(to: .breakActivity(activity.id, ActivityContext(entryPoint: .suggestion, sessionID: sessionID, suggestionRank: rank)))
    }

    func openShelfFromCompletion() {
        container.focus.acknowledgeCompletion(returningToFocus: false)
        reload()
        router.go(to: .breakShelf)
    }

    func returnToFocusFromCompletion() {
        container.focus.acknowledgeCompletion(returningToFocus: true)
        reload()
        router.go(to: .focusHome)
    }

    // MARK: - Break activities

    func beginActivity(_ id: BreakActivityID, context: ActivityContext) -> ActivityUsage {
        let usage = container.breaks.begin(id, context: context)
        reload()
        return usage
    }

    func finishActivity(_ usageID: UUID, outcome: ActivityOutcome) {
        container.breaks.finish(usageID: usageID, outcome: outcome)
        reload()
    }

    /// From an activity's end state or header: back to the shelf.
    func returnToShelf() {
        router.popToShelf()
    }

    /// From an activity's end state: straight back to Focus.
    func returnToFocusFromActivity() {
        container.focus.recordReturnToFocus()
        router.popToShelf()
        router.go(to: .focusHome)
    }

    // MARK: - Tasks

    @discardableResult
    func createTask(title: String, select: Bool = true) -> TaskItem? {
        let task = container.taskController.create(title: title)
        if let task, select {
            container.preferences.update { $0.selectedTaskID = task.id }
        }
        reload()
        return task
    }

    func selectTask(_ id: UUID?) {
        container.preferences.update { $0.selectedTaskID = id }
        reload()
    }

    func setTaskCompleted(_ id: UUID, _ completed: Bool) {
        container.taskController.setCompleted(id: id, completed)
        if completed, preferences.selectedTaskID == id {
            container.preferences.update { $0.selectedTaskID = nil }
        }
        reload()
    }

    func renameTask(_ id: UUID, to title: String) {
        container.taskController.rename(id: id, to: title)
        reload()
    }

    func deleteTask(_ id: UUID) {
        container.taskController.delete(id: id)
        if preferences.selectedTaskID == id {
            container.preferences.update { $0.selectedTaskID = nil }
        }
        reload()
    }

    // MARK: - Presets & preferences

    func savePreset(_ preset: FocusPreset) {
        container.preferences.save(preset)
        reload()
    }

    func setDefaultPreset(_ id: FocusPresetID) {
        container.preferences.setDefaultPreset(id)
        reload()
    }

    func setAnimationIntensity(_ intensity: AnimationIntensity) {
        container.preferences.update { $0.animationIntensity = intensity }
        reload()
    }

    func completeOnboarding(goal: OnboardingGoal) {
        container.preferences.completeOnboarding(goal: goal)
        reload()
        router.go(to: .focusHome)
    }

    func replayOnboarding() {
        container.preferences.resetOnboarding()
        reload()
    }

    func resetAllData() {
        if activeSession != nil {
            container.focus.endEarly()
        }
        container.preferences.resetAllData()
        suggestionCache.removeAll()
        isAudioMuted = false
        router.completion = nil
        router.sheet = nil
        router.focusPath = []
        router.breakPath = []
        router.mePath = []
        router.selectedTab = .focus
        reload()
    }

    // MARK: - Deep links & NFC

    /// Handles still:// links from NFC tags, Shortcuts, or other apps.
    func handle(url: URL) {
        routeFocusLink(url, source: .deepLink)
    }

    /// The in-app NFC simulator runs the exact same route as a real tag.
    func simulateFocusCard(presetID: FocusPresetID) {
        guard let preset = presets.first(where: { $0.id == presetID }) else { return }
        routeFocusLink(preset.startURL, source: .nfcSimulator)
    }

    private func routeFocusLink(_ url: URL, source: SessionSource) {
        guard preferences.hasCompletedOnboarding else {
            notice = StillNotice(text: "Finish setting up Still, then tap your card again.")
            return
        }
        switch container.nfcRouter.route(url) {
        case .startPreset(let presetID):
            container.events.track(.nfcPresetRouted, EventProperties().preset(presetID).source(source))
            startFocus(presetID: presetID, source: source)
        case .unknownPreset(let presetID):
            container.events.track(.nfcPresetRouted, EventProperties().preset(presetID).source(source))
            startFocus(presetID: presetID, source: source)
        case .notAFocusLink:
            notice = StillNotice(text: "That link isn't a Still focus link.")
        }
    }
}

// MARK: - Activity notes

extension AppState {
    /// Autosaves text from Brain Dump or Creative Prompt. Returns the note's ID
    /// (nil when the text is empty and any earlier version was removed).
    func autosaveNote(text: String, kind: ActivityNoteKind, activityID: BreakActivityID, promptID: String?, existingID: UUID?) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let existingID { container.breaks.deleteNote(id: existingID) }
            return nil
        }
        return container.breaks.saveNote(text: trimmed, kind: kind, activityID: activityID,
                                         promptID: promptID, existingID: existingID)?.id ?? existingID
    }

    func recentNotes(_ kind: ActivityNoteKind, limit: Int = 5) -> [ActivityNote] {
        container.breaks.recentNotes(kind: kind, limit: limit)
    }
}
