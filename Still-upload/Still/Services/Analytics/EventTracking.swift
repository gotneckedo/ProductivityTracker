import Foundation

/// Local, typed event tracking. Nothing leaves the device in V1.
protocol EventTracking: AnyObject {
    func track(_ name: AppEventName, _ properties: EventProperties)
    var recentEvents: [AppEvent] { get }
    func clear()
}

extension EventTracking {
    func track(_ name: AppEventName) {
        track(name, EventProperties())
    }
}

/// A future, opt-in, privacy-respecting destination (for example, an
/// aggregate export the user reviews first). V1 registers none.
protocol EventDestination: AnyObject {
    func receive(_ event: AppEvent)
}

/// Keeps a bounded in-memory log for development and debugging.
final class LocalEventTracker: EventTracking {
    private let clock: Clock
    private let capacity: Int
    private var events: [AppEvent] = []
    private var destinations: [EventDestination]

    init(clock: Clock, capacity: Int = 500, destinations: [EventDestination] = []) {
        self.clock = clock
        self.capacity = capacity
        self.destinations = destinations
    }

    func track(_ name: AppEventName, _ properties: EventProperties) {
        let event = AppEvent(id: UUID(), name: name, timestamp: clock.now, properties: properties)
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
        destinations.forEach { $0.receive(event) }
    }

    var recentEvents: [AppEvent] { events }

    func clear() {
        events.removeAll()
    }

    /// Funnel counts, e.g. focus_completed → break_activity_started.
    func count(of name: AppEventName) -> Int {
        events.filter { $0.name == name }.count
    }
}
