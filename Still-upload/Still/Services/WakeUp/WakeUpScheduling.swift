import Foundation

/// What should happen after the wake-up entry point opens Still.
enum WakeUpStopMethod: String, Codable, CaseIterable, Hashable {
    case button
    case focusCard

    var displayName: String {
        switch self {
        case .button: return "Button"
        case .focusCard: return "Focus Card"
        }
    }
}

/// The complete Wake up plan. Its schedule remains compatible with the existing
/// iOS 17 Morning Start notification implementation.
struct WakeUpPlan: Hashable {
    var schedule: MorningStartPlan
    var stopWith: WakeUpStopMethod

    static let standard = WakeUpPlan(schedule: .standard, stopWith: .button)

    func validated() -> WakeUpPlan {
        WakeUpPlan(schedule: schedule.validated(), stopWith: stopWith)
    }
}

enum WakeUpDelivery: Equatable {
    /// Real local-notification delivery on iOS 17+. It follows silent mode and Focus.
    case notificationFallback
    /// A local DEBUG/CI demonstration layered over the notification fallback.
    case previewNotificationFallback
    /// Reserved for the future iOS 26 AlarmKit implementation.
    case alarmKit
}

/// Boundary between the complete Wake up planning UI and system delivery.
/// AlarmKit can replace the fallback without changing the screen or saved plan.
protocol WakeUpScheduling: AnyObject {
    var delivery: WakeUpDelivery { get }
    var isWaitingForFocusCard: Bool { get }
    func schedule(_ plan: WakeUpPlan)
    func cancel()
    func simulateOpening() -> Bool
    func simulateFocusCardTap() -> Bool
}

/// The shipping iOS 17 fallback. This schedules a genuine local notification,
/// but does not claim that it is an alarm or that a card can prevent dismissal.
final class NotificationWakeUpScheduler: WakeUpScheduling {
    private let notifications: MorningStartScheduling

    init(notifications: MorningStartScheduling) {
        self.notifications = notifications
    }

    var delivery: WakeUpDelivery { .notificationFallback }
    var isWaitingForFocusCard: Bool { false }

    func schedule(_ plan: WakeUpPlan) {
        notifications.scheduleMorningStart(plan.validated().schedule)
    }

    func cancel() {
        notifications.cancelMorningStart()
    }

    func simulateOpening() -> Bool { false }
    func simulateFocusCardTap() -> Bool { false }
}

/// DEBUG/CI-demo-only behavior for reviewing the card-waiting flow without an
/// AlarmKit-capable phone. Notification delivery remains the real fallback.
final class PreviewWakeUpScheduler: WakeUpScheduling {
    private let fallback: MorningStartScheduling
    private(set) var scheduledPlan: WakeUpPlan?
    private(set) var isWaitingForFocusCard = false

    init(fallback: MorningStartScheduling) {
        self.fallback = fallback
    }

    var delivery: WakeUpDelivery { .previewNotificationFallback }

    func schedule(_ plan: WakeUpPlan) {
        let validated = plan.validated()
        scheduledPlan = validated.schedule.isEnabled && !validated.schedule.weekdays.isEmpty ? validated : nil
        isWaitingForFocusCard = false
        fallback.scheduleMorningStart(validated.schedule)
    }

    func cancel() {
        scheduledPlan = nil
        isWaitingForFocusCard = false
        fallback.cancelMorningStart()
    }

    /// Simulates the future alarm opening Still. It never claims the system
    /// alarm itself is still sounding or cannot be dismissed.
    func simulateOpening() -> Bool {
        guard let plan = scheduledPlan else { return false }
        isWaitingForFocusCard = plan.stopWith == .focusCard
        return true
    }

    func simulateFocusCardTap() -> Bool {
        guard isWaitingForFocusCard else { return false }
        isWaitingForFocusCard = false
        return true
    }
}

/// The intentional real/stand-in boundary. Keep the iOS 17 notification path
/// until AlarmKit is available in the build SDK and its behavior is verified on
/// a physical device.
enum WakeUpSchedulerFactory {
    static func live(fallback: MorningStartScheduling) -> WakeUpScheduling {
        #if canImport(AlarmKit) && os(iOS)
        if #available(iOS 26, *) {
            // TODO(P9-AlarmKit): return AlarmKitWakeUpScheduler(fallback: fallback)
            // after mapping WakeUpPlan to AlarmKit and verifying the system-owned
            // stop UI on device. Do not emulate an un-dismissible alarm here.
        }
        #endif
        return NotificationWakeUpScheduler(notifications: fallback)
    }
}
