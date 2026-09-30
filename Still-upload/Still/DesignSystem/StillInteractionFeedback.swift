import SwiftUI

#if canImport(UIKit)
import AudioToolbox
import UIKit

/// Executes Still's semantic feedback policy with Apple system frameworks.
/// No event is sent off-device, and disabled preferences short-circuit before
/// allocating an engine or playing a device sound.
@MainActor
enum StillInteractionFeedback {
    static func fire(_ kind: InteractionFeedbackKind, preferences: UserPreferences) {
        if preferences.hapticsEnabled {
            switch kind.haptic {
            case .light:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium:
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .selection:
                UISelectionFeedbackGenerator().selectionChanged()
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .error:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }

        // The system's short tick is only an optional interface confirmation;
        // it never starts or replaces a Focus soundscape.
        if preferences.interactionSoundsEnabled && kind.emitsSound {
            AudioServicesPlaySystemSound(SystemSoundID(1104))
        }
    }
}
#else
/// Keeps previews and non-iOS compilation paths explicit without pretending to
/// produce device feedback where Apple hardware APIs are unavailable.
@MainActor
enum StillInteractionFeedback {
    static func fire(_ kind: InteractionFeedbackKind, preferences: UserPreferences) {}
}
#endif
