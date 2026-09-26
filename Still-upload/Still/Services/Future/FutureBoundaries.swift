import Foundation

// Boundaries for capabilities that depend on hardware, permissions, or Apple
// approval. Each has a real or honest stand-in implementation.
// See FUTURE_CAPABILITIES.md for the plan behind each one.

// MARK: V3 — Voice task capture

struct CapturedTaskDraft: Hashable {
    var title: String
    var dueAt: Date?
    var scheduledAt: Date?
}

// MARK: V3 — Calendar sync

struct ExternalCalendarEvent: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var startsAt: Date
    var endsAt: Date
    var sourceIdentifier: String
}

enum CalendarAccess: Equatable {
    case notDetermined
    case granted
    case denied
    case unavailable
}

/// Read-only calendar events for the day timeline. V3 ships Apple Calendar
/// (EventKit, on device). Google Calendar needs OAuth and a privacy review.
protocol CalendarAdapter: AnyObject {
    var access: CalendarAccess { get }
    func requestAccess() async -> CalendarAccess
    func events(from start: Date, to end: Date) -> [ExternalCalendarEvent]
}

/// No calendar: tests, previews, and devices without EventKit.
final class NoCalendarAdapter: CalendarAdapter {
    var access: CalendarAccess
    var stubbedEvents: [ExternalCalendarEvent]

    init(access: CalendarAccess = .unavailable, events: [ExternalCalendarEvent] = []) {
        self.access = access
        self.stubbedEvents = events
    }

    func requestAccess() async -> CalendarAccess { access }

    func events(from start: Date, to end: Date) -> [ExternalCalendarEvent] {
        guard access == .granted else { return [] }
        return stubbedEvents.filter { $0.startsAt < end && $0.endsAt > start }
    }
}
