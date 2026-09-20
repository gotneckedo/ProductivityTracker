#if canImport(UserNotifications)
import Foundation
import UserNotifications

/// Schedules local phase-end reminders and the Morning Start prompt with
/// UserNotifications.
///
/// Phase reminders and Morning Start use separate identifier prefixes, so
/// replacing one never clears the other. Reminders are not shown while the
/// app is in the foreground (no delegate opts in); the in-app screen handles it.
final class UserNotificationScheduler: LocalNotificationScheduling, MorningStartScheduling {
    private static let sessionPrefix = "still.session."

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

    /// Identifiers of the phase reminders this process scheduled. Touched on
    /// the main thread only.
    private var trackedSessionIdentifiers: Set<String> = []

    func schedule(_ boundaries: [PhaseBoundary], sessionID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: Array(trackedSessionIdentifiers))
        trackedSessionIdentifiers = Set(Self.add(boundaries, sessionID: sessionID, to: center))
        sweepStaleSessionReminders()
    }

    /// Removes phase reminders left by an earlier launch, keeping Morning Start
    /// and the reminders just scheduled.
    private func sweepStaleSessionReminders() {
        let center = self.center
        center.getPendingNotificationRequests { [weak self] pending in
            DispatchQueue.main.async {
                guard let self else { return }
                let stale = pending.map(\.identifier).filter {
                    $0.hasPrefix(Self.sessionPrefix) && !self.trackedSessionIdentifiers.contains($0)
                }
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }
        }
    }

    @discardableResult
    private static func add(_ boundaries: [PhaseBoundary], sessionID: UUID, to center: UNUserNotificationCenter) -> [String] {
        let now = Date()
        var identifiers: [String] = []
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
            let identifier = NotificationCopy.identifier(sessionID: sessionID, phaseIndex: boundary.endingPhaseIndex)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { _ in }
            identifiers.append(identifier)
        }
        return identifiers
    }

    /// Clears phase reminders only; Morning Start keeps its schedule.
    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: Array(trackedSessionIdentifiers))
        trackedSessionIdentifiers = []
        sweepStaleSessionReminders()
        let notificationCenter = center
        notificationCenter.getDeliveredNotifications { delivered in
            let identifiers = delivered.map(\.request.identifier).filter { $0.hasPrefix(Self.sessionPrefix) }
            notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    // MARK: Morning Start

    func scheduleMorningStart(_ plan: MorningStartPlan) {
        cancelMorningStart()
        let plan = plan.validated()
        guard plan.isEnabled else { return }
        for weekday in plan.weekdays.sorted() {
            let content = UNMutableNotificationContent()
            content.title = MorningStartCopy.title
            content.body = MorningStartCopy.body
            content.sound = .default
            content.userInfo = ["url": DeepLink.startFocus(presetID: plan.presetID).url.absoluteString]
            var components = DateComponents()
            components.weekday = weekday
            components.hour = plan.hour
            components.minute = plan.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: MorningStartCopy.identifierPrefix + String(weekday),
                                                content: content, trigger: trigger)
            center.add(request) { _ in }
        }
    }

    func cancelMorningStart() {
        let identifiers = (1...7).map { MorningStartCopy.identifierPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
#endif
