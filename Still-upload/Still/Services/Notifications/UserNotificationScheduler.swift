#if canImport(UserNotifications)
import Foundation
import UserNotifications

/// Schedules local phase-end reminders with UserNotifications.
///
/// Still only uses notifications for phase ends, so replacing the schedule
/// clears all of the app's pending requests. Reminders are not shown while the
/// app is in the foreground (no delegate opts in); the in-app screen handles it.
final class UserNotificationScheduler: LocalNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        default:
            return .granted
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func schedule(_ boundaries: [PhaseBoundary], sessionID: UUID) {
        center.removeAllPendingNotificationRequests()
        let now = Date()
        for boundary in boundaries {
            let interval = boundary.date.timeIntervalSince(now)
            guard interval > 1 else { continue }
            let copy = NotificationCopy.content(for: boundary)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.threadIdentifier = sessionID.uuidString
            content.categoryIdentifier = NotificationCopy.categoryIdentifier
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: NotificationCopy.identifier(sessionID: sessionID, phaseIndex: boundary.endingPhaseIndex),
                content: content,
                trigger: trigger
            )
            center.add(request) { _ in }
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
#endif
