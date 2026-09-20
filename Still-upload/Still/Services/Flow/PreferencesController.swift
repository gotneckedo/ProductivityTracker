import Foundation

/// Onboarding, presets, appearance, and data reset.
final class PreferencesController {
    private let preferences: PreferencesStore
    private let presets: PresetRepository
    private let recordStore: RecordStore
    private let events: EventTracking
    private let notifications: LocalNotificationScheduling
    private let audio: AmbientAudioPlaying
    var onPersistenceError: ((Error) -> Void)?

    init(
        preferences: PreferencesStore,
        presets: PresetRepository,
        recordStore: RecordStore,
        events: EventTracking,
        notifications: LocalNotificationScheduling,
        audio: AmbientAudioPlaying
    ) {
        self.preferences = preferences
        self.presets = presets
        self.recordStore = recordStore
        self.events = events
        self.notifications = notifications
        self.audio = audio
    }

    var current: UserPreferences { preferences.load() }

    func update(_ change: (inout UserPreferences) -> Void) {
        var prefs = preferences.load()
        change(&prefs)
        preferences.save(prefs)
    }

    // MARK: Onboarding

    /// Stores the answer and personalizes built-in presets. The user lands on
    /// Focus with the 25-minute default session.
    func completeOnboarding(goal: OnboardingGoal) {
        let personalization = Personalization(goal: goal)
        presets.resetToBuiltIns(personalization: personalization)
        update { prefs in
            prefs.onboardingGoal = goal
            prefs.hasCompletedOnboarding = true
            prefs.defaultPresetID = .defaultPreset
        }
        events.track(.onboardingCompleted, EventProperties().goal(goal))
    }

    /// Replays onboarding without touching sessions or tasks.
    func resetOnboarding() {
        update { prefs in
            prefs.hasCompletedOnboarding = false
        }
    }

    // MARK: Presets

    func preset(_ id: FocusPresetID) -> FocusPreset {
        presets.preset(id: id) ?? PresetCatalog.defaultPreset(personalization: Personalization(goal: current.onboardingGoal))
    }

    func allPresets() -> [FocusPreset] {
        presets.allPresets()
    }

    func save(_ preset: FocusPreset) {
        presets.save(preset)
    }

    var canCreatePreset: Bool {
        presets.allPresets().count < PresetCatalog.maximumPresets
    }

    /// Copies `base` into a new, editable preset with its own link.
    @discardableResult
    func createPreset(named raw: String, basedOn base: FocusPreset) -> FocusPreset? {
        guard canCreatePreset, let name = FocusPreset.normalizedName(raw) else { return nil }
        var preset = base
        preset.id = FocusPreset.makeCustomID()
        preset.name = name
        preset.isBuiltIn = false
        presets.save(preset)
        events.track(.presetCreated, EventProperties().timerMode(preset.timer.mode))
        return preset
    }

    func renamePreset(_ id: FocusPresetID, to raw: String) {
        guard var preset = presets.preset(id: id), let name = FocusPreset.normalizedName(raw) else { return }
        preset.name = name
        presets.save(preset)
    }

    /// Deletes a custom preset. If it was the default, Default takes over.
    func deletePreset(_ id: FocusPresetID) {
        guard !PresetCatalog.builtInIDs.contains(id) else { return }
        presets.delete(id: id)
        if current.defaultPresetID == id {
            update { $0.defaultPresetID = .defaultPreset }
        }
    }

    func setDefaultPreset(_ id: FocusPresetID) {
        guard presets.preset(id: id) != nil else { return }
        update { $0.defaultPresetID = id }
    }

    // MARK: Reset

    /// Deletes every local record and setting. Returns to onboarding.
    func resetAllData() {
        notifications.cancelAll()
        audio.stop()
        do {
            try recordStore.deleteAll()
        } catch {
            onPersistenceError?(error)
        }
        preferences.reset()
        presets.resetToBuiltIns(personalization: Personalization(goal: nil))
        events.clear()
    }
}
