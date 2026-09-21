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
    let habits: HabitRepository
    let artifacts: ArtifactRepository
    let readingProgress: ReadingProgressRepository
    let blockingSelections: BlockingSelectionStore

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
    let bookLibrary: BookLibrary
    let calendarAdapter: CalendarAdapter
    let googleCalendar: GoogleCalendarAdapter
    let morningStart: MorningStartScheduling
    let wakeUp: WakeUpScheduling
    let purchases: PurchaseService
    let focusCardOffering: FocusCardOffering
    let widgetSnapshots: WidgetSnapshotWriting
    /// Nil where speech capture isn't available (tests, Linux, flag off).
    let speech: SpeechTaskCapturing?

    // Controllers
    let focus: FocusFlowController
    let breaks: BreakFlowController
    let taskController: TaskController
    let preferences: PreferencesController
    let journalController: JournalController
    let habitController: HabitController
    let books: BookReadingController

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
        bookLibrary: BookLibrary = EmptyBookLibrary(),
        calendarAdapter: CalendarAdapter = NoCalendarAdapter(),
        googleCalendar: GoogleCalendarAdapter = NoGoogleCalendarAdapter(),
        morningStart: MorningStartScheduling = RecordingMorningStartScheduler(),
        wakeUp: WakeUpScheduling? = nil,
        purchases: PurchaseService = NoPurchaseService(),
        focusCardOffering: FocusCardOffering = NoFocusCardOffering(),
        widgetSnapshots: WidgetSnapshotWriting = RecordingWidgetSnapshotWriter(),
        speech: SpeechTaskCapturing? = nil,
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
        habits = StoredHabitRepository(store: recordStore)
        artifacts = StoredArtifactRepository(store: recordStore)
        readingProgress = StoredReadingProgressRepository(store: recordStore)
        blockingSelections = KeyValueBlockingSelectionStore(store: keyValueStore)

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
        self.bookLibrary = bookLibrary
        self.calendarAdapter = calendarAdapter
        self.googleCalendar = flags.googleCalendarPreview ? googleCalendar : NoGoogleCalendarAdapter()
        self.morningStart = morningStart
        self.wakeUp = wakeUp ?? NotificationWakeUpScheduler(notifications: morningStart)
        self.purchases = flags.seasonalPurchasesPreview ? purchases : NoPurchaseService()
        self.focusCardOffering = flags.brandedFocusCardPreview ? focusCardOffering : NoFocusCardOffering()
        self.widgetSnapshots = widgetSnapshots
        self.speech = flags.voiceCapture ? speech : nil

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
        journalController = JournalController(clock: clock, calendar: calendar, journal: journal, events: tracker)
        habitController = HabitController(clock: clock, calendar: calendar, habits: habits, events: tracker)
        books = BookReadingController(library: bookLibrary, progress: readingProgress, clock: clock)
    }

    /// Fully in-memory container for tests and SwiftUI previews.
    static func inMemory(
        clock: Clock = ManualClock(),
        calendar: Calendar = .current,
        flags: FeatureFlags = .current,
        notifications: LocalNotificationScheduling = RecordingNotificationScheduler(),
        audio: AmbientAudioPlaying = SilentAmbientAudioPlayer(),
        calendarAdapter: CalendarAdapter = NoCalendarAdapter(),
        googleCalendar: GoogleCalendarAdapter? = nil,
        purchases: PurchaseService? = nil,
        focusCardOffering: FocusCardOffering? = nil,
        bookLibrary: BookLibrary = EmptyBookLibrary()
    ) -> DependencyContainer {
        let morningStart = RecordingMorningStartScheduler()
        return DependencyContainer(
            flags: flags,
            clock: clock,
            calendar: calendar,
            recordStore: InMemoryRecordStore(),
            keyValueStore: InMemoryKeyValueStore(),
            notifications: notifications,
            audio: audio,
            blocking: MockFocusBlockingService(),
            liveActivity: NoopLiveActivityUpdater(),
            bookLibrary: bookLibrary,
            calendarAdapter: calendarAdapter,
            googleCalendar: googleCalendar ?? (flags.googleCalendarPreview
                ? SampleGoogleCalendarAdapter(now: clock.now, calendar: calendar)
                : NoGoogleCalendarAdapter()),
            morningStart: morningStart,
            wakeUp: flags.wakeUpPreview
                ? PreviewWakeUpScheduler(fallback: morningStart)
                : NotificationWakeUpScheduler(notifications: morningStart),
            purchases: purchases ?? (flags.seasonalPurchasesPreview ? LocalPurchaseService() : NoPurchaseService()),
            focusCardOffering: focusCardOffering ?? (flags.brandedFocusCardPreview
                ? PlaceholderFocusCardOffering()
                : NoFocusCardOffering())
        )
    }
}
