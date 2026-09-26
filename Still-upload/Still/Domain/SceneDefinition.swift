import Foundation

extension Identifier where Tag == SceneTag {
    static let rainyBedroom: SceneID = "rainyBedroom"
    static let libraryLight: SceneID = "libraryLight"
    static let trainWindow: SceneID = "trainWindow"
    static let nightCity: SceneID = "nightCity"
    static let autumnWindow: SceneID = "autumnWindow"
    static let snowDay: SceneID = "snowDay"
    static let springRain: SceneID = "springRain"
}

/// Which drawing routine renders a scene. Several scenes may share a kind;
/// seasonal variants would reuse a kind with a new palette.
enum SceneRendererKind: String, Codable, Hashable {
    case rainyBedroom
    case libraryLight
    case trainWindow
    case nightCity
}

/// Platform-neutral 24-bit color so scene data stays testable and serializable.
struct RGBColor: Codable, Hashable {
    var hex: UInt32

    init(_ hex: UInt32) {
        self.hex = hex
    }

    var red: Double { Double((hex >> 16) & 0xFF) / 255 }
    var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    var blue: Double { Double(hex & 0xFF) / 255 }
}

struct ScenePalette: Codable, Hashable {
    /// Deepest tone: dark navy shadow.
    var shadow: RGBColor
    /// Room or sky base.
    var base: RGBColor
    /// Secondary surface (walls, far hills, shelves).
    var surface: RGBColor
    /// Warm light: lamps, lit windows.
    var warmLight: RGBColor
    /// Soft accent: plants, book spines.
    var accent: RGBColor
    /// Secondary accent.
    var accentAlt: RGBColor
    /// Small highlights: rain, stars, dust.
    var highlight: RGBColor
}

/// Small looping motions a scene may use. Metadata only; renderers decide how.
enum SceneMotionElement: String, Codable, Hashable {
    case rain
    case lampGlow
    case dustMotes
    case passingLandscape
    case windowLights
    case leafSway
}

/// A focus environment, defined entirely as data.
struct SceneDefinition: Codable, Identifiable, Hashable {
    var id: SceneID
    var name: String
    var summary: String
    var rendererKind: SceneRendererKind
    var palette: ScenePalette
    var unlockRule: SceneUnlockRule
    var soundAffinity: AmbientSourceID?
    var motionElements: [SceneMotionElement]
    var accessibilityDescription: String
    /// Name of Still's original raster room sprite. Nil preserves the
    /// code-drawn renderer as a safe fallback for future or imported scenes.
    var spriteAssetName: String?
    /// Cosmetic entitlement only. Every session-earned scene keeps this nil.
    var entitlementKey: String?
    var sortOrder: Int
}

/// How much ambient motion scenes use. `still` renders a single frame.
/// Reduce Motion always resolves to `still`.
enum AnimationIntensity: String, Codable, CaseIterable, Hashable {
    case full
    case gentle
    case still

    var displayName: String {
        switch self {
        case .full: return "Full"
        case .gentle: return "Gentle"
        case .still: return "Still"
        }
    }

    /// Frames per second for scene loops. Zero means a static frame.
    var framesPerSecond: Double {
        switch self {
        case .full: return 12
        case .gentle: return 6
        case .still: return 0
        }
    }

    func resolved(reduceMotion: Bool) -> AnimationIntensity {
        reduceMotion ? .still : self
    }
}
