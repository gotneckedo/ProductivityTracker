import Foundation

/// Builds and holds every service, repository, and controller.
///
/// Platform-neutral so tests and previews can build a complete in-memory app.
/// The live, device-backed container is built in `DependencyContainer+Live.swift`.
final class DependencyContainer {
    let flags: FeatureFlags
    let clock: Clock
    let calendar: Calendar

    // Storage
    let recordStore: RecordStore
    let keyValueStore: KeyValueStore
    let sessions: SessionRepository
    let tasks: TaskRepository
    let usages: ActivityUsageRepository
    let notes: ActivityNoteRepository
    let journal: JournalRepository
    let puzzleProgress: PuzzleProgressRepository
    let preferencesStore: PreferencesStore
    let presets: PresetRepository

    // Services
    let timer: FocusTimerService
    let notifications: LocalNotificationScheduling
    let audio: AmbientAudioPlaying
    let blocking: FocusBlockingService
    let liveActivity: LiveActivityUpdating
    let events: EventTracking
    let nfcRouter: NFCFocusPresetRouting
    let readingLibrary: ReadingContentProviding
    let puzzles: PuzzleProviding

    // Controllers
    let focus: FocusFlowController
    let breaks: BreakFlowController
    let taskController: TaskController
    let preferences: PreferencesController

    /// A non-nil value means storage fell back to memory; the UI says so calmly.
    let storageNotice: String?

    init(
        flags: FeatureFlags = .v1,
        clock: Clock,
        calendar: Calendar = .current,
        recordStore: RecordStore,
        keyValueStore: KeyValueStore,
        notifications: LocalNotificationScheduling,
        audio: AmbientAudioPlaying,
        blocking: FocusBlockingService,
        liveActivity: LiveActivityUpdating,
        events: EventTracking? = nil,
        storageNotice: String? = nil
    ) {
        self.flags = flags
        self.clock = clock
        self.calendar = calendar
        self.recordStore = recordStore
        self.keyValueStore = keyValueStore
        self.storageNotice = storageNotice

        sessions = StoredSessionRepository(store: recordStore)
        tasks = StoredTaskRepository(store: recordStore)
        usages = StoredActivityUsageRepository(store: recordStore)
        notes = StoredActivityNoteRepository(store: recordStore)
        journal = StoredJournalRepository(store: recordStore)
        puzzleProgress = StoredPuzzleProgressRepository(store: recordStore)
        preferencesStore = CodablePreferencesStore(store: keyValueStore)
        presets = StoredPresetRepository(store: keyValueStore)

        timer = FocusTimerEngine()
        self.notifications = notifications
        self.audio = audio
        self.blocking = blocking
        self.liveActivity = liveActivity
        let tracker = events ?? LocalEventTracker(clock: clock)
        self.events = tracker
        nfcRouter = DeepLinkPresetRouter(knownPresetIDs: Set(presets.allPresets().map(\.id)))
        readingLibrary = BundledReadingLibrary()
        puzzles = BundledPuzzleLibrary()

        focus = FocusFlowController(
            clock: clock,
            timer: timer,
            sessions: sessions,
            tasks: tasks,
            presets: presets,
            preferences: preferencesStore,
            notifications: notifications,
            audio: audio,
            blocking: blocking,
            liveActivity: liveActivity,
            events: tracker
        )
        breaks = BreakFlowController(clock: clock, calendar: calendar, usages: usages, notes: notes, events: tracker)
        taskController = TaskController(clock: clock, calendar: calendar, tasks: tasks)
        preferences = PreferencesController(
            preferences: preferencesStore,
            presets: presets,
            recordStore: recordStore,
            events: tracker,
            notifications: notifications,
            audio: audio
        )
    }

    /// Fully in-memory container for tests and SwiftUI previews.
    static func inMemory(
        clock: Clock = ManualClock(),
        calendar: Calendar = .current,
        flags: FeatureFlags = .v1,
        notifications: LocalNotificationScheduling = RecordingNotificationScheduler(),
        audio: AmbientAudioPlaying = SilentAmbientAudioPlayer()
    ) -> DependencyContainer {
        DependencyContainer(
            flags: flags,
            clock: clock,
            calendar: calendar,
            recordStore: InMemoryRecordStore(),
            keyValueStore: InMemoryKeyValueStore(),
            notifications: notifications,
            audio: audio,
            blocking: MockFocusBlockingService(),
            liveActivity: NoopLiveActivityUpdater()
        )
    }
}
