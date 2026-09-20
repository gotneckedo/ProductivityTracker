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

    static func builtIns(personalization: Personalization) -> [FocusPreset] {
        [defaultPreset(personalization: personalization), study]
    }
}
