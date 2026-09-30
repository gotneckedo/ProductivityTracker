import Foundation

/// A calm local rendering state for the room during a focus session. It is
/// derived from the session that is already running; it has no score, meter,
/// unlock, or care obligation.
enum RoomSessionState: String, Codable, CaseIterable, Equatable {
    case idle
    case focusing
    case breakTime
    case justFinished

    init(activePhase: FocusPhaseKind?) {
        guard let activePhase else {
            self = .idle
            return
        }
        self = activePhase.isBreak ? .breakTime : .focusing
    }

    var accessibilityDescription: String {
        switch self {
        case .idle:
            return "The room is resting between sessions."
        case .focusing:
            return "Focus is underway at the desk."
        case .breakTime:
            return "A short break is in progress."
        case .justFinished:
            return "The focus session has just finished."
        }
    }

    var visualDetail: String {
        switch self {
        case .idle: return "quiet room"
        case .focusing: return "warm desk pool"
        case .breakTime: return "cool floor wash"
        case .justFinished: return "soft completion glow"
        }
    }
}
