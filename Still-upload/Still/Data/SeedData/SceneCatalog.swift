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

    static let autumnWindow = SceneDefinition(
        id: .autumnWindow,
        name: "Autumn Window",
        summary: "Copper leaves beyond a warm study desk.",
        rendererKind: .rainyBedroom,
        palette: ScenePalette(
            shadow: RGBColor(0x30242C), base: RGBColor(0x5A3D3B), surface: RGBColor(0x8B5A3C),
            warmLight: RGBColor(0xF3C77D), accent: RGBColor(0xB66A3C),
            accentAlt: RGBColor(0x7F8B57), highlight: RGBColor(0xF6DEC0)
        ),
        unlockRule: .initiallyUnlocked,
        soundAffinity: .fireplace,
        motionElements: [.leafSway, .lampGlow],
        accessibilityDescription: "A warm study room with copper autumn colors beyond the window and a softly glowing desk lamp.",
        entitlementKey: PurchaseProductCatalog.supporter,
        sortOrder: 100
    )

    static let snowDay = SceneDefinition(
        id: .snowDay,
        name: "Snow Day",
        summary: "Blue snowlight and a quiet lamp.",
        rendererKind: .rainyBedroom,
        palette: ScenePalette(
            shadow: RGBColor(0x263146), base: RGBColor(0x526780), surface: RGBColor(0x8196AB),
            warmLight: RGBColor(0xF0D29A), accent: RGBColor(0xA9C4C8),
            accentAlt: RGBColor(0xD2B5C0), highlight: RGBColor(0xEDF5F5)
        ),
        unlockRule: .initiallyUnlocked,
        soundAffinity: .fireplace,
        motionElements: [.rain, .lampGlow],
        accessibilityDescription: "A blue winter room with pale snow outside the window and a warm lamp beside the desk.",
        entitlementKey: PurchaseProductCatalog.supporter,
        sortOrder: 101
    )

    static let springRain = SceneDefinition(
        id: .springRain,
        name: "Spring Rain",
        summary: "Fresh leaves after an afternoon shower.",
        rendererKind: .libraryLight,
        palette: ScenePalette(
            shadow: RGBColor(0x29423F), base: RGBColor(0x739B93), surface: RGBColor(0xA5BDA5),
            warmLight: RGBColor(0xF1DFA4), accent: RGBColor(0x7CA36E),
            accentAlt: RGBColor(0xD69FA5), highlight: RGBColor(0xE7F1DC)
        ),
        unlockRule: .initiallyUnlocked,
        soundAffinity: .rain,
        motionElements: [.rain, .leafSway],
        accessibilityDescription: "A green spring study room after rain, with fresh leaves and a bright window.",
        entitlementKey: PurchaseProductCatalog.supporter,
        sortOrder: 102
    )

    /// Free forever: these are earned only through the person's own sessions.
    static let all: [SceneDefinition] = [rainyBedroom, libraryLight, trainWindow, nightCity]
    static let seasonal: [SceneDefinition] = [autumnWindow, snowDay, springRain]
    static let completeCatalog: [SceneDefinition] = all + seasonal

    static func scene(_ id: SceneID) -> SceneDefinition {
        completeCatalog.first { $0.id == id } ?? rainyBedroom
    }
}
