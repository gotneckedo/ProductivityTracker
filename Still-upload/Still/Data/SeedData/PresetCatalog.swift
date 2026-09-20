import Foundation

/// Built-in presets. Users can edit them; edits are stored as overrides.
enum PresetCatalog {
    static func defaultPreset(personalization: Personalization = Personalization(goal: nil)) -> FocusPreset {
        FocusPreset(
            id: .defaultPreset,
            name: "Default",
            timer: .standard,
            sceneID: .rainyBedroom,
            renderMode: personalization.preferredRenderMode,
            ambientMix: personalization.startsWithSound ? .gentleRain : .silent,
            taskBehavior: .useSelectedTask,
            blockerIntent: .none,
            isBuiltIn: true
        )
    }

    /// Study: two 50-minute blocks with a 10-minute break, calm mode, rain.
    static let study = FocusPreset(
        id: .study,
        name: "Study",
        timer: TimerConfiguration(
            mode: .pomodoro,
            focusDuration: 50 * 60,
            breakDuration: 10 * 60,
            longBreakDuration: 20 * 60,
            longBreakInterval: 0,
            cycleCount: 2,
            autoStartBreaks: true,
            autoStartFocus: false,
            routineID: nil
        ),
        sceneID: .rainyBedroom,
        renderMode: .calm,
        ambientMix: .gentleRain,
        taskBehavior: .useSelectedTask,
        blockerIntent: .soft,
        isBuiltIn: true
    )

    /// Deep Work: one long 90-minute block, strict blocking intent, no sound.
    /// Library Light is used once it's unlocked; until then the session falls
    /// back to the first scene.
    static let deepWork = FocusPreset(
        id: .deepWork,
        name: "Deep Work",
        timer: TimerConfiguration(
            mode: .countdown,
            focusDuration: 90 * 60,
            breakDuration: 15 * 60,
            longBreakDuration: 15 * 60,
            longBreakInterval: 0,
            cycleCount: 1,
            autoStartBreaks: true,
            autoStartFocus: false,
            routineID: nil
        ),
        sceneID: .libraryLight,
        renderMode: .scene,
        ambientMix: .silent,
        taskBehavior: .useSelectedTask,
        blockerIntent: .strict,
        isBuiltIn: true
    )

    /// Quick Focus: 15 minutes for when starting is the hard part.
    static let quickFocus = FocusPreset(
        id: .quickFocus,
        name: "Quick Focus",
        timer: TimerConfiguration(
            mode: .countdown,
            focusDuration: 15 * 60,
            breakDuration: 5 * 60,
            longBreakDuration: 15 * 60,
            longBreakInterval: 0,
            cycleCount: 1,
            autoStartBreaks: true,
            autoStartFocus: false,
            routineID: nil
        ),
        sceneID: .rainyBedroom,
        renderMode: .scene,
        ambientMix: .gentleRain,
        taskBehavior: .useSelectedTask,
        blockerIntent: .soft,
        isBuiltIn: true
    )

    static let builtInIDs: [FocusPresetID] = [.defaultPreset, .study, .deepWork, .quickFocus]

    static func builtIns(personalization: Personalization) -> [FocusPreset] {
        [defaultPreset(personalization: personalization), study, deepWork, quickFocus]
    }

    /// Most presets a person can keep. Enough for a card per room.
    static let maximumPresets = 10
}
