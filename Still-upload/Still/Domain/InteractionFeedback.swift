import Foundation

/// The semantic vocabulary for Still's tactile responses. Views ask for a
/// meaning rather than choosing device APIs, so feedback stays consistent and
/// can be disabled locally without changing a product action.
enum InteractionFeedbackKind: String, CaseIterable, Equatable {
    case rowPressed
    case roomObjectTapped
    case roomObjectOpened
    case focusStarted
    case focusCompleted
    case roomObjectEarned
    case taskMarkedDone
    case swipeActionCommitted
    case soundscapeToggled
    case roomChanged
    case breakEnded
    case catTapped
    case invalidPuzzleEntry

    enum Haptic: Equatable {
        case light
        case medium
        case selection
        case success
        case error
    }

    var haptic: Haptic {
        switch self {
        case .rowPressed, .roomObjectTapped, .taskMarkedDone, .catTapped:
            return .light
        case .roomObjectOpened, .focusStarted, .swipeActionCommitted:
            return .medium
        case .soundscapeToggled, .roomChanged:
            return .selection
        case .focusCompleted, .roomObjectEarned, .breakEnded:
            return .success
        case .invalidPuzzleEntry:
            return .error
        }
    }

    /// Sound is optional and deliberately limited to state changes. A normal
    /// row press remains tactile-only even when interaction sounds are on.
    var emitsSound: Bool {
        switch self {
        case .focusStarted, .focusCompleted, .roomObjectEarned,
             .soundscapeToggled, .breakEnded, .invalidPuzzleEntry:
            return true
        default:
            return false
        }
    }
}
