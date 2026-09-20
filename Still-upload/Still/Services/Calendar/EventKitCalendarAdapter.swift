#if canImport(EventKit) && os(iOS)
import EventKit
import Foundation

/// Read-only Apple Calendar events for the day timeline. Nothing is written
/// to the calendar and nothing leaves the device.
///
/// Needs `NSCalendarsFullAccessUsageDescription` in Info.plist (iOS 17+).
final class EventKitCalendarAdapter: CalendarAdapter {
    private let store = EKEventStore()

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .fullAccess, .authorized:
            return .granted
        case .denied, .restricted, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        if access != .notDetermined { return access }
        do {
            let granted = try await store.requestFullAccessToEvents()
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    func events(from start: Date, to end: Date) -> [ExternalCalendarEvent] {
        guard access == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .map { event in
                ExternalCalendarEvent(
                    id: event.calendarItemIdentifier,
                    title: event.title ?? "Busy",
                    startsAt: event.startDate,
                    endsAt: event.endDate,
                    sourceIdentifier: event.calendar?.calendarIdentifier ?? "calendar"
                )
            }
    }
}
#endif
