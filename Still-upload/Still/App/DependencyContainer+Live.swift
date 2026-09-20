import Foundation

extension DependencyContainer {
    /// The on-device container: SwiftData storage, real notifications and
    /// audio, the honest blocking mock, and Live Activities only when enabled.
    static func live(flags: FeatureFlags = .v1) -> DependencyContainer {
        let recordStore: RecordStore
        var storageNotice: String?
        do {
            recordStore = try SwiftDataRecordStore()
        } catch {
            // Keep the app usable; say plainly that nothing will be saved.
            recordStore = InMemoryRecordStore()
            storageNotice = "Storage isn't available right now, so this session won't be saved."
        }

        let liveActivity: LiveActivityUpdating
        #if canImport(ActivityKit) && os(iOS)
        liveActivity = flags.liveActivities ? ActivityKitLiveActivityUpdater() : NoopLiveActivityUpdater()
        #else
        liveActivity = NoopLiveActivityUpdater()
        #endif

        return DependencyContainer(
            flags: flags,
            clock: SystemClock(),
            calendar: .autoupdatingCurrent,
            recordStore: recordStore,
            keyValueStore: UserDefaultsKeyValueStore(),
            notifications: UserNotificationScheduler(),
            audio: AVAmbientAudioPlayer(),
            // V1 is simulation-only by design. Swap in FamilyControlsBlockingService
            // when the entitlement is approved and flags.appBlocking is on.
            blocking: MockFocusBlockingService(),
            liveActivity: liveActivity,
            storageNotice: storageNotice
        )
    }
}
