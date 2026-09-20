import Foundation

/// How a task entered the app. V1 only creates `.typed` tasks.
enum TaskCaptureSource: String, Codable, Hashable {
    case typed
    /// V3: speech capture parsed into a task. Not created in V1.
    case voice
    /// V3: imported from a calendar adapter. Not created in V1.
    case calendarImport
}

/// V3 homework metadata. Always nil in V1; present so the model does not need a rewrite.
struct HomeworkMetadata: Codable, Hashable {
    var course: String?
    var assignmentKind: String?
}

/// A deliberately small, typed task.
///
/// Marking a task done is separate from completing a focus session.
struct TaskItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var createdAt: Date
    var completedAt: Date?
    /// The most recent session this task was focused on.
    var attachedSessionID: UUID?
    /// How many completed sessions were spent on this task.
    var completedSessionCount: Int
    var captureSource: TaskCaptureSource

    // MARK: Future capacity (unused in V1 UI)
    var scheduledAt: Date?
    var dueAt: Date?
    var calendarEventID: String?
    var homework: HomeworkMetadata?

    var isCompleted: Bool { completedAt != nil }

    static let maximumTitleLength = 120

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date,
        completedAt: Date? = nil,
        attachedSessionID: UUID? = nil,
        completedSessionCount: Int = 0,
        captureSource: TaskCaptureSource = .typed,
        scheduledAt: Date? = nil,
        dueAt: Date? = nil,
        calendarEventID: String? = nil,
        homework: HomeworkMetadata? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.attachedSessionID = attachedSessionID
        self.completedSessionCount = completedSessionCount
        self.captureSource = captureSource
        self.scheduledAt = scheduledAt
        self.dueAt = dueAt
        self.calendarEventID = calendarEventID
        self.homework = homework
    }

    /// Trims whitespace, collapses internal runs of whitespace, and caps length.
    /// Returns nil when nothing meaningful remains.
    static func normalizedTitle(_ raw: String) -> String? {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maximumTitleLength))
    }
}
