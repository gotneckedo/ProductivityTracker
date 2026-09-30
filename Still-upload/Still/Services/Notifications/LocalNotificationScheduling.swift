import Foundation

enum NotificationAuthorization: Equatable {
    case notDetermined
    case granted
    case denied
}

/// Local phase-end reminders. The in-app completion path never depends on
/// notifications; they are a courtesy when the app is in the background.
protocol LocalNotificationScheduling: AnyObject {
    func authorizationStatus() async -> NotificationAuthorization
    /// Asks the system. Returns whether reminders are allowed.
    func requestAuthorization() async -> Bool
    /// Replaces any pending reminders for the session with these boundaries.
    func schedule(_ boundaries: [PhaseBoundary], sessionID: UUID)
    func cancelAll()
}

/// Used in tests and previews. Records what would have been scheduled.
final class RecordingNotificationScheduler: LocalNotificationScheduling {
    var authorization: NotificationAuthorization
    var grantsOnRequest: Bool
    private(set) var requestCount = 0
    private(set) var scheduled: [PhaseBoundary] = []
    private(set) var scheduledSessionID: UUID?

    init(authorization: NotificationAuthorization = .notDetermined, grantsOnRequest: Bool = true) {
        self.authorization = authorization
        self.grantsOnRequest = grantsOnRequest
    }

    func authorizationStatus() async -> NotificationAuthorization { authorization }

    func requestAuthorization() async -> Bool {
        requestCount += 1
        authorization = grantsOnRequest ? .granted : .denied
        return grantsOnRequest
    }

    func schedule(_ boundaries: [PhaseBoundary], sessionID: UUID) {
        guard authorization == .granted else {
            scheduled = []
            return
        }
        scheduled = boundaries
        scheduledSessionID = sessionID
    }

    func cancelAll() {
        scheduled = []
        scheduledSessionID = nil
    }
}
