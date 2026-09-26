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

    /// Low Energy deliberately asks for a small, manageable round rather than
    /// treating a tired day as a failed normal day.
    static let lowEnergy = FocusPreset(
        id: .lowEnergy,
        name: "Low Energy",
        timer: TimerConfiguration(
            mode: .countdown,
            focusDuration: 10 * 60,
            breakDuration: 3 * 60,
            longBreakDuration: 10 * 60,
            longBreakInterval: 0,
            cycleCount: 1,
            autoStartBreaks: false,
            autoStartFocus: false,
            routineID: nil
        ),
        sceneID: .rainyBedroom,
        renderMode: .calm,
        ambientMix: .gentleRain,
        taskBehavior: .useSelectedTask,
        blockerIntent: .none,
        isBuiltIn: true
    )

    /// A two-minute on-ramp for moments when opening the task is the work.
    static let tinyStart = FocusPreset(
        id: .tinyStart,
        name: "Tiny Start",
        timer: TimerConfiguration(
            mode: .countdown,
            focusDuration: 5 * 60,
            breakDuration: 2 * 60,
            longBreakDuration: 5 * 60,
            longBreakInterval: 0,
            cycleCount: 1,
            autoStartBreaks: false,
            autoStartFocus: false,
            routineID: nil
        ),
        sceneID: .rainyBedroom,
        renderMode: .calm,
        ambientMix: .gentleRain,
        taskBehavior: .useSelectedTask,
        blockerIntent: .none,
        isBuiltIn: true
    )

    static let builtInIDs: [FocusPresetID] = [.defaultPreset, .study, .deepWork, .quickFocus, .lowEnergy, .tinyStart]

    static func builtIns(personalization: Personalization) -> [FocusPreset] {
        [defaultPreset(personalization: personalization), study, deepWork, quickFocus, lowEnergy, tinyStart]
    }

    /// Most presets a person can keep. Enough for a card per room.
    static let maximumPresets = 10
}
