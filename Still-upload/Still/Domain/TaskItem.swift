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

/// A tiny, optional checklist within a task. Steps stay local and are separate
/// from the task's own completed state, so a focus session can surface the next
/// concrete action without making completion automatic.
struct TaskStep: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var completedAt: Date?

    init(id: UUID = UUID(), title: String, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.completedAt = completedAt
    }

    var isCompleted: Bool { completedAt != nil }
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
    /// Optional, short checklist used on the task card and active focus slab.
    var steps: [TaskStep]

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
        steps: [TaskStep] = [],
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
        self.steps = steps
        self.scheduledAt = scheduledAt
        self.dueAt = dueAt
        self.calendarEventID = calendarEventID
        self.homework = homework
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, completedAt, attachedSessionID, completedSessionCount
        case captureSource, steps, scheduledAt, dueAt, calendarEventID, homework
    }

    /// Older local records predate task steps. Decode those as an empty list
    /// rather than discarding a person's existing tasks during the visual update.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        attachedSessionID = try container.decodeIfPresent(UUID.self, forKey: .attachedSessionID)
        completedSessionCount = try container.decodeIfPresent(Int.self, forKey: .completedSessionCount) ?? 0
        captureSource = try container.decodeIfPresent(TaskCaptureSource.self, forKey: .captureSource) ?? .typed
        steps = try container.decodeIfPresent([TaskStep].self, forKey: .steps) ?? []
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
        calendarEventID = try container.decodeIfPresent(String.self, forKey: .calendarEventID)
        homework = try container.decodeIfPresent(HomeworkMetadata.self, forKey: .homework)
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
