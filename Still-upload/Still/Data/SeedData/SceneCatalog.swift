import Foundation

/// Original starter scenes. Unlock thresholds are data, not view logic.
enum SceneCatalog {
    static let rainyBedroom = SceneDefinition(
        id: .rainyBedroom,
        name: "Rainy Bedroom",
        summary: "Rain on the window, a lamp left on.",
        rendererKind: .rainyBedroom,
        palette: ScenePalette(
            shadow: RGBColor(0x1F2537),
            base: RGBColor(0x2E3650),
            surface: RGBColor(0x404B67),
            warmLight: RGBColor(0xF2C98B),
            accent: RGBColor(0x8FAF8A),
            accentAlt: RGBColor(0xE3B5B8),
            highlight: RGBColor(0xA9C1D9)
        ),
        unlockRule: .initiallyUnlocked,
        soundAffinity: .rain,
        motionElements: [.rain, .lampGlow],
        accessibilityDescription: "A dim bedroom at night. Rain runs down a tall window, a small plant sits on the sill, and a desk lamp glows warm.",
        entitlementKey: nil,
        sortOrder: 0
    )

    static let libraryLight = SceneDefinition(
        id: .libraryLight,
        name: "Library Light",
        summary: "Late sun across tall shelves.",
        rendererKind: .libraryLight,
        palette: ScenePalette(
            shadow: RGBColor(0x2A2838),
            base: RGBColor(0x3B3447),
            surface: RGBColor(0x6E5C4F),
            warmLight: RGBColor(0xF4D9A0),
            accent: RGBColor(0x9FB4C7),
            accentAlt: RGBColor(0xC98E7A),
            highlight: RGBColor(0xFBEFD5)
        ),
        unlockRule: .completedSessions(7),
        soundAffinity: .fireplace,
        motionElements: [.dustMotes, .lampGlow],
        accessibilityDescription: "A quiet library corner. Shelves of colored book spines, a tall window letting in a warm shaft of light, and dust drifting slowly through it.",
        entitlementKey: nil,
        sortOrder: 1
    )

    static let trainWindow = SceneDefinition(
        id: .trainWindow,
        name: "Train Window",
        summary: "Hills sliding past at dusk.",
        rendererKind: .trainWindow,
        palette: ScenePalette(
            shadow: RGBColor(0x232A3D),
            base: RGBColor(0xF2C4A8),
            surface: RGBColor(0x9FB4C7),
            warmLight: RGBColor(0xEED79A),
            accent: RGBColor(0x7E9C83),
            accentAlt: RGBColor(0x4B5A72),
            highlight: RGBColor(0xFBF1DC)
        ),
        unlockRule: .completedSessions(15),
        soundAffinity: .rain,
        motionElements: [.passingLandscape],
        accessibilityDescription: "The view from a train window at dusk. Layers of soft hills drift past under a peach sky with a low sun.",
        entitlementKey: nil,
        sortOrder: 2
    )

    static let nightCity = SceneDefinition(
        id: .nightCity,
        name: "Night City",
        summary: "Windows lighting up across the street.",
        rendererKind: .nightCity,
        palette: ScenePalette(
            shadow: RGBColor(0x161B2B),
            base: RGBColor(0x232B45),
            surface: RGBColor(0x33405E),
            warmLight: RGBColor(0xEED79A),
            accent: RGBColor(0x9FB4C7),
            accentAlt: RGBColor(0xE3B5B8),
            highlight: RGBColor(0xFBF1DC)
        ),
        unlockRule: .completedSessions(25),
        soundAffinity: .cafe,
        motionElements: [.windowLights],
        accessibilityDescription: "A city skyline at night under a pale moon. Apartment windows slowly light up and go dark.",
        entitlementKey: nil,
        sortOrder: 3
    )

    static let all: [SceneDefinition] = [rainyBedroom, libraryLight, trainWindow, nightCity]

    static func scene(_ id: SceneID) -> SceneDefinition {
        all.first { $0.id == id } ?? rainyBedroom
    }
}
