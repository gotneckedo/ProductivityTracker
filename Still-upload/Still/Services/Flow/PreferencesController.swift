import Foundation

/// Onboarding, presets, appearance, and data reset.
final class PreferencesController {
    private let preferences: PreferencesStore
    private let presets: PresetRepository
    private let recordStore: RecordStore
    private let events: EventTracking
    private let notifications: LocalNotificationScheduling
    private let audio: AmbientAudioPlaying
    private let alternateAppIcons: AlternateAppIconChanging
    var onPersistenceError: ((Error) -> Void)?
    var onIconChangeUnavailable: (() -> Void)?
    var onIconChangeError: ((Error) -> Void)?

    init(
        preferences: PreferencesStore,
        presets: PresetRepository,
        recordStore: RecordStore,
        events: EventTracking,
        notifications: LocalNotificationScheduling,
        audio: AmbientAudioPlaying,
        alternateAppIcons: AlternateAppIconChanging = UnavailableAlternateAppIconChanger()
    ) {
        self.preferences = preferences
        self.presets = presets
        self.recordStore = recordStore
        self.events = events
        self.notifications = notifications
        self.audio = audio
        self.alternateAppIcons = alternateAppIcons
    }

    var current: UserPreferences { preferences.load() }

    func update(_ change: (inout UserPreferences) -> Void) {
        var prefs = preferences.load()
        change(&prefs)
        preferences.save(prefs)
    }

    // MARK: Onboarding

    /// Backward-compatible entry point for existing flows and fixtures.
    func completeOnboarding(goal: OnboardingGoal) {
        completeOnboarding(OnboardingAnswers(goal: goal))
    }

    /// Stores whichever answers the person chose (every question is skippable)
    /// and personalizes built-in presets. The user lands on a 25-minute session.
    func completeOnboarding(_ answers: OnboardingAnswers) {
        let personalization = Personalization(goal: answers.goal, breakAppeal: answers.breakAppeal)
        presets.resetToBuiltIns(personalization: personalization)
        update { prefs in
            prefs.onboardingGoal = answers.goal
            prefs.breakAppeal = answers.breakAppeal
            prefs.appAccentPalette = answers.appAccentPalette
            prefs.hasCompletedOnboarding = true
            prefs.defaultPresetID = .defaultPreset
        }
        if let goal = answers.goal {
            events.track(.onboardingCompleted, EventProperties().goal(goal))
        } else {
            events.track(.onboardingCompleted)
        }
        applyIcon(for: answers.appAccentPalette)
    }

    /// Replays onboarding without touching sessions or tasks.
    func resetOnboarding() {
        update { prefs in
            prefs.hasCompletedOnboarding = false
        }
    }

    /// Targeted preference edits used from Me. They never reset onboarding,
    /// sessions, tasks, presets, or another answer.
    func setOnboardingGoal(_ goal: OnboardingGoal?) {
        update { $0.onboardingGoal = goal }
    }

    func setBreakAppeal(_ appeal: BreakAppeal?) {
        update { $0.breakAppeal = appeal }
    }

    func setAppAccentPalette(_ palette: AppAccentPalette) {
        update { $0.appAccentPalette = palette }
        applyIcon(for: palette)
    }

    func setCatCoat(_ coat: CatCoat) {
        update { $0.catCoat = coat }
    }

    func setCatName(_ raw: String?) {
        update { $0.catName = CatName.normalized(raw) }
    }

    func saveSoundscape(_ soundscape: SavedSoundscape) {
        update { prefs in
            let normalized = SavedSoundscape(id: soundscape.id, name: soundscape.name, mix: soundscape.mix.normalized())
            if let index = prefs.savedSoundscapes.firstIndex(where: { $0.id == normalized.id }) {
                prefs.savedSoundscapes[index] = normalized
            } else {
                prefs.savedSoundscapes.append(normalized)
            }
        }
    }

    func deleteSoundscape(_ id: UUID) {
        update { $0.savedSoundscapes.removeAll { $0.id == id } }
    }

    var supportsAlternateAppIcons: Bool {
        alternateAppIcons.supportsAlternateIcons
    }

    private func applyIcon(for palette: AppAccentPalette) {
        alternateAppIcons.setAlternateIconName(palette.alternateIconName) { [weak self] result in
            switch result {
            case .success(.changed):
                break
            case .success(.unavailable):
                self?.onIconChangeUnavailable?()
            case .failure(let error):
                self?.onIconChangeError?(error)
            }
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
        applyIcon(for: .mint)
        events.clear()
    }
}
