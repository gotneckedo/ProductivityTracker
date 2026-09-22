import Foundation

extension DependencyContainer {
    /// The on-device container: SwiftData storage, real notifications and
    /// audio, Apple Calendar, speech capture, the home-screen widget, and
    /// Live Activities. Blocking stays the honest mock until
    /// `flags.appBlocking` is on (it needs Apple's entitlement approval).
    static func live(flags: FeatureFlags = .current) -> DependencyContainer {
        let recordStore: RecordStore
        var storageNotice: String?
        do {
            recordStore = try SwiftDataRecordStore()
        } catch {
            // Keep the app usable; say plainly that nothing will be saved.
            recordStore = InMemoryRecordStore()
            storageNotice = "Storage isn't available right now, so this session won't be saved."
        }

        let keyValueStore = UserDefaultsKeyValueStore()
        let clock = SystemClock()

        let liveActivity: LiveActivityUpdating
        #if canImport(ActivityKit) && os(iOS)
        liveActivity = flags.liveActivities ? ActivityKitLiveActivityUpdater() : NoopLiveActivityUpdater()
        #else
        liveActivity = NoopLiveActivityUpdater()
        #endif

        let blocking: FocusBlockingService
        #if canImport(FamilyControls) && canImport(ManagedSettings) && os(iOS)
        blocking = flags.appBlocking
            ? FamilyControlsBlockingService(selections: KeyValueBlockingSelectionStore(store: keyValueStore))
            : MockFocusBlockingService()
        #else
        blocking = MockFocusBlockingService()
        #endif

        let calendarAdapter: CalendarAdapter
        #if canImport(EventKit) && os(iOS)
        calendarAdapter = flags.calendarEvents ? EventKitCalendarAdapter() : NoCalendarAdapter()
        #else
        calendarAdapter = NoCalendarAdapter()
        #endif

        let speech: SpeechTaskCapturing?
        #if canImport(Speech) && os(iOS)
        speech = SpeechRecognizerCapture()
        #else
        speech = nil
        #endif

        let widgetSnapshots: WidgetSnapshotWriting
        #if canImport(WidgetKit) && os(iOS)
        widgetSnapshots = AppGroupWidgetSnapshotWriter()
        #else
        widgetSnapshots = RecordingWidgetSnapshotWriter()
        #endif

        let notifications = UserNotificationScheduler()
        let wakeUp: WakeUpScheduling
        #if DEBUG
        wakeUp = flags.wakeUpPreview
            ? PreviewWakeUpScheduler(fallback: notifications)
            : WakeUpSchedulerFactory.live(fallback: notifications)
        #else
        wakeUp = WakeUpSchedulerFactory.live(fallback: notifications)
        #endif

        let purchases: PurchaseService
        #if canImport(StoreKit) && os(iOS) && DEBUG
        purchases = flags.seasonalPurchasesPreview ? StoreKitPurchaseService() : NoPurchaseService()
        #else
        purchases = NoPurchaseService()
        #endif

        let googleCalendar: GoogleCalendarAdapter
        let focusCardOffering: FocusCardOffering
        #if DEBUG
        googleCalendar = flags.googleCalendarPreview
            ? SampleGoogleCalendarAdapter(now: clock.now, calendar: .autoupdatingCurrent)
            : NoGoogleCalendarAdapter()
        focusCardOffering = flags.brandedFocusCardPreview
            ? PlaceholderFocusCardOffering()
            : NoFocusCardOffering()
        #else
        googleCalendar = NoGoogleCalendarAdapter()
        focusCardOffering = NoFocusCardOffering()
        #endif

        // Folder references can land either at the bundle root or inside the
        // synchronized Resources group. Resolve the known four files
        // recursively so Short Read never depends on an Xcode copy layout.
        let bundledBooks = BundledBookLocator.urls(in: Bundle.main)
        let bookLibrary = FileBookLibrary(directory: FileBookLibrary.defaultDirectory(), bundledURLs: bundledBooks, clock: clock)

        return DependencyContainer(
            flags: flags,
            clock: clock,
            calendar: .autoupdatingCurrent,
            recordStore: recordStore,
            keyValueStore: keyValueStore,
            notifications: notifications,
            audio: AVAmbientAudioPlayer(),
            blocking: blocking,
            liveActivity: liveActivity,
            bookLibrary: bookLibrary,
            calendarAdapter: calendarAdapter,
            googleCalendar: googleCalendar,
            morningStart: notifications,
            wakeUp: wakeUp,
            purchases: purchases,
            focusCardOffering: focusCardOffering,
            widgetSnapshots: widgetSnapshots,
            alternateAppIcons: UIKitAlternateAppIconChanger(),
            speech: speech,
            storageNotice: storageNotice
        )
    }
}
