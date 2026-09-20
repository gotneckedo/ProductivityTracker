import Foundation

/// A small daily habit, kept separate from tasks on purpose: a task gets done
/// once, a habit is a yes/no for each day.
struct HabitDefinition: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var sortOrder: Int
    /// Archived habits keep their history but leave the daily list.
    var archivedAt: Date?

    var isArchived: Bool { archivedAt != nil }

    static let maximumTitleLength = 60
    /// A short list stays calm. More than this becomes a chore chart.
    static let maximumActive = 5
}

/// One "yes" for one habit on one day. No record means "not today", which is
/// never shown as a failure.
struct HabitCheckIn: Codable, Hashable, Identifiable {
    var id: String { "\(habitID.uuidString)-\(Int(day.timeIntervalSinceReferenceDate))" }
    var habitID: UUID
    /// Start of the calendar day.
    var day: Date
    var createdAt: Date
}

/// A habit with today's state, ready for display.
struct HabitDay: Hashable, Identifiable {
    var habit: HabitDefinition
    var isDoneToday: Bool
    /// Consecutive days including today or yesterday.
    var currentRun: Int
    /// Done-or-not for the last seven days, oldest first.
    var lastSevenDays: [Bool]

    var id: UUID { habit.id }
}
