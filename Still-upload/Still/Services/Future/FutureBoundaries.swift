import Foundation

// Boundaries for later releases. These are protocols and value types only:
// nothing here is wired into the V1 UI, and nothing pretends to work.
// See FUTURE_CAPABILITIES.md for the plan behind each one.

// MARK: V2 — AlarmKit wake-up hand-off

/// A wake-up that opens into today's tasks and a queued first session.
/// Verify the current AlarmKit API and entitlement before implementing.
struct WakeUpPlan: Codable, Hashable {
    var id: UUID
    var hour: Int
    var minute: Int
    var weekdays: Set<Int>
    var firstSessionPresetID: FocusPresetID
}

protocol WakeUpScheduling: AnyObject {
    var isAvailable: Bool { get }
    func schedule(_ plan: WakeUpPlan) async throws
    func cancel(planID: UUID) async
}

// MARK: V2 — Habits (kept separate from TaskItem on purpose)

struct HabitDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
}

protocol HabitRepository: AnyObject {
    func allHabits() -> [HabitDefinition]
    func save(_ habit: HabitDefinition) throws
}

// MARK: V3 — Voice task capture

struct CapturedTaskDraft: Hashable {
    var title: String
    var dueAt: Date?
    var scheduledAt: Date?
}

/// Speech → parsed task. Requires Speech and microphone permissions later.
protocol TaskCaptureService: AnyObject {
    var isAvailable: Bool { get }
    func captureTask() async throws -> CapturedTaskDraft
}

// MARK: V3 — Calendar sync

struct ExternalCalendarEvent: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var startsAt: Date
    var endsAt: Date
    var sourceIdentifier: String
}

/// EventKit or Google Calendar adapter. OAuth and privacy review come first.
protocol CalendarAdapter: AnyObject {
    var isConnected: Bool { get }
    func events(from start: Date, to end: Date) async throws -> [ExternalCalendarEvent]
}

// MARK: V3 — Widgets

/// A compact summary a WidgetKit extension can render without the app running.
struct FocusSummarySnapshot: Codable, Hashable {
    var generatedAt: Date
    var todayFocus: TimeInterval
    var currentStreak: Int
    var defaultPresetID: FocusPresetID
}

protocol FocusSummaryProviding: AnyObject {
    func currentSummary() -> FocusSummarySnapshot
}
