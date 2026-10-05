import Foundation

/// Direct Google Calendar boundary. The real implementation will require OAuth,
/// a privacy policy, and Google's verification; no credentials ship in V1.
protocol GoogleCalendarAdapter: AnyObject {
    var access: CalendarAccess { get }
    var isStandIn: Bool { get }
    func requestAccess() async -> CalendarAccess
    func disconnect()
    func events(from start: Date, to end: Date) -> [ExternalCalendarEvent]
}

final class NoGoogleCalendarAdapter: GoogleCalendarAdapter {
    var access: CalendarAccess { .unavailable }
    var isStandIn: Bool { false }

    func requestAccess() async -> CalendarAccess { .unavailable }
    func disconnect() {}
    func events(from start: Date, to end: Date) -> [ExternalCalendarEvent] { [] }
}

/// DEBUG/CI-demo-only sample data. It performs no sign-in and no network call.
final class SampleGoogleCalendarAdapter: GoogleCalendarAdapter {
    private(set) var access: CalendarAccess
    private let sampleEvents: [ExternalCalendarEvent]

    init(now: Date, calendar: Calendar = .current, access: CalendarAccess = .notDetermined) {
        self.access = access
        let day = calendar.startOfDay(for: now)
        let classStart = calendar.date(byAdding: .hour, value: 10, to: day) ?? now
        let studyStart = calendar.date(byAdding: .hour, value: 16, to: day) ?? now
        sampleEvents = [
            ExternalCalendarEvent(
                id: "google-preview-class",
                title: "History class · Sample",
                startsAt: classStart,
                endsAt: classStart.addingTimeInterval(50 * 60),
                sourceIdentifier: "google-preview"
            ),
            ExternalCalendarEvent(
                id: "google-preview-study",
                title: "Study group · Sample",
                startsAt: studyStart,
                endsAt: studyStart.addingTimeInterval(60 * 60),
                sourceIdentifier: "google-preview"
            )
        ]
    }

    var isStandIn: Bool { true }

    func requestAccess() async -> CalendarAccess {
        access = .granted
        return access
    }

    func disconnect() {
        access = .notDetermined
    }

    func events(from start: Date, to end: Date) -> [ExternalCalendarEvent] {
        guard access == .granted else { return [] }
        return sampleEvents.filter { $0.startsAt < end && $0.endsAt > start }
    }
}
