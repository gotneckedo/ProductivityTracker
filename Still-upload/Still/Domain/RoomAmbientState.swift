import Foundation

/// The local, non-gamified environmental state of a room. It reflects the
/// clock only; it does not track behavior, introduce rewards, or require care.
enum RoomAmbientState: String, CaseIterable, Codable, Equatable {
    case morning
    case afternoon
    case dusk
    case night
    /// A focused session intentionally uses the restrained scene treatment,
    /// rather than pretending that the time outside has changed.
    case focus

    init(hour: Int) {
        switch hour {
        case 5..<11: self = .morning
        case 11..<17: self = .afternoon
        case 17..<20: self = .dusk
        default: self = .night
        }
    }

    init(dayPhaseName: String) {
        self = Self(rawValue: dayPhaseName) ?? .night
    }

    var visualDetail: String {
        switch self {
        case .morning: return "soft dust motes"
        case .afternoon: return "a long sunbeam"
        case .dusk: return "a low rose sun"
        case .night: return "three distant stars"
        case .focus: return "a low desk glow"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .morning:
            return "Morning light at a clear window with \(visualDetail)."
        case .afternoon:
            return "Afternoon light at an open window with \(visualDetail)."
        case .dusk:
            return "Dusk light at a rosy window with \(visualDetail)."
        case .night:
            return "Night light at a deep-blue window with \(visualDetail)."
        case .focus:
            return "A quiet focused room with \(visualDetail)."
        }
    }
}
