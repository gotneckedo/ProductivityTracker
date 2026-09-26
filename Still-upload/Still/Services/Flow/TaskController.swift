import Foundation

/// Fast, typed task capture. Due dates, a scheduled time, and a class name are
/// optional details added after the fact, so capture stays one line.
final class TaskController {
    private let clock: Clock
    private let calendar: Calendar
    private let tasks: TaskRepository
    var onPersistenceError: ((Error) -> Void)?

    init(clock: Clock, calendar: Calendar, tasks: TaskRepository) {
        self.clock = clock
        self.calendar = calendar
        self.tasks = tasks
    }

    /// Creates a task from typed text. Returns nil for blank input.
    @discardableResult
    func create(title raw: String) -> TaskItem? {
        guard let title = TaskItem.normalizedTitle(raw) else { return nil }
        let task = TaskItem(title: title, createdAt: clock.now)
        return persist(task) ? task : nil
    }

    /// Creates a task from a spoken or parsed draft.
    @discardableResult
    func create(from draft: CapturedTaskDraft, source: TaskCaptureSource) -> TaskItem? {
        guard let title = TaskItem.normalizedTitle(draft.title) else { return nil }
        let task = TaskItem(title: title, createdAt: clock.now, captureSource: source,
                            scheduledAt: draft.scheduledAt, dueAt: draft.dueAt)
        return persist(task) ? task : nil
    }

    /// Optional details. Capture remains one line; this richer presentation is
    /// attached later from the detail view.
    func updateDetails(
        id: UUID,
        dueAt: Date?,
        scheduledAt: Date?,
        subject: Subject?,
        plannedDuration: TimeInterval? = nil,
        dayPeriod: TaskDayPeriod = .anytime,
        repeatRule: TaskRepeatRule = .once
    ) {
        guard var task = tasks.task(id: id) else { return }
        task.dueAt = dueAt
        task.scheduledAt = scheduledAt
        task.subject = subject.flatMap { candidate in
            Subject.normalizedName(candidate.name).map { Subject(name: $0, color: candidate.color) }
        }
        task.plannedDuration = plannedDuration.map { min(max($0, 5 * 60), 12 * 3600) }
        task.dayPeriod = dayPeriod
        task.repeatRule = repeatRule.normalized(anchor: scheduledAt ?? dueAt ?? task.createdAt, calendar: calendar)
        // Once a record has first-class subject data, avoid keeping a second
        // independently editable course string around.
        if var homework = task.homework {
            homework.course = nil
            task.homework = homework.assignmentKind == nil ? nil : homework
        }
        persist(task)
    }

    /// Compatibility entry point for callers still passing a course. Existing
    /// subjects keep their color; a migrated course receives a stable one.
    func updateDetails(id: UUID, dueAt: Date?, scheduledAt: Date?, course: String?) {
        let existing = tasks.task(id: id)?.subject
        let name = course.flatMap(Subject.normalizedName)
        let subject = name.map { Subject(name: $0, color: existing?.color ?? .migratedColor(for: $0)) }
        updateDetails(id: id, dueAt: dueAt, scheduledAt: scheduledAt, subject: subject)
    }

    /// Open tasks with a due date or scheduled time, soonest first.
    func upcomingTasks(limit: Int = 20) -> [TaskItem] {
        tasks.allTasks()
            .filter { !$0.isCompleted && ($0.dueAt != nil || $0.scheduledAt != nil) }
            .sorted { ($0.scheduledAt ?? $0.dueAt ?? .distantFuture) < ($1.scheduledAt ?? $1.dueAt ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }

    func rename(id: UUID, to raw: String) {
        guard let title = TaskItem.normalizedTitle(raw), var task = tasks.task(id: id) else { return }
        task.title = title
        persist(task)
    }

    /// Marking done is separate from finishing a focus session.
    func setCompleted(id: UUID, _ completed: Bool) {
        guard var task = tasks.task(id: id) else { return }
        if task.repeatRule.isRepeating {
            setCompleted(id: id, on: clock.now, completed)
            return
        }
        task.completedAt = completed ? (task.completedAt ?? clock.now) : nil
        persist(task)
    }

    /// Completion belongs to the represented occurrence, not every future copy.
    func setCompleted(id: UUID, on day: Date, _ completed: Bool) {
        guard var task = tasks.task(id: id) else { return }
        guard task.repeatRule.isRepeating else {
            setCompleted(id: id, completed)
            return
        }
        let occurrenceDay = calendar.startOfDay(for: day)
        task.completedOccurrenceDays.removeAll { calendar.isDate($0, inSameDayAs: occurrenceDay) }
        if completed { task.completedOccurrenceDays.append(occurrenceDay) }
        persist(task)
    }

    @discardableResult
    func addStep(taskID: UUID, title raw: String) -> Bool {
        guard var task = tasks.task(id: taskID),
              let title = TaskItem.normalizedTitle(raw) else { return false }
        task.steps.append(TaskStep(title: String(title.prefix(80))))
        return persist(task)
    }

    func toggleStep(taskID: UUID, stepID: UUID) {
        guard var task = tasks.task(id: taskID), let index = task.steps.firstIndex(where: { $0.id == stepID }) else { return }
        task.steps[index].completedAt = task.steps[index].completedAt == nil ? clock.now : nil
        persist(task)
    }

    func deleteStep(taskID: UUID, stepID: UUID) {
        guard var task = tasks.task(id: taskID) else { return }
        task.steps.removeAll { $0.id == stepID }
        persist(task)
    }

    func delete(id: UUID) {
        do {
            try tasks.delete(id: id)
        } catch {
            onPersistenceError?(error)
        }
    }

    func task(id: UUID) -> TaskItem? {
        tasks.task(id: id)
    }

    /// Open tasks (oldest first), then tasks finished today (latest first).
    func todaysTasks() -> [TaskItem] {
        let all = tasks.allTasks()
        let oneTime = all.filter { !$0.repeatRule.isRepeating }
        let recurringToday = all
            .filter { $0.repeatRule.isRepeating && $0.occurs(on: clock.now, calendar: calendar) }
            .map { task -> TaskItem in
                var presented = task
                presented.completedAt = task.isCompleted(on: clock.now, calendar: calendar)
                    ? calendar.startOfDay(for: clock.now)
                    : nil
                return presented
            }
        let visible = oneTime + recurringToday
        let open = visible.filter { !$0.isCompleted }.sorted { $0.createdAt < $1.createdAt }
        let doneToday = visible
            .filter { task in task.completedAt.map { calendar.isDate($0, inSameDayAs: clock.now) } ?? false }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return open + doneToday
    }

    @discardableResult
    private func persist(_ task: TaskItem) -> Bool {
        do {
            try tasks.save(task)
            return true
        } catch {
            onPersistenceError?(error)
            return false
        }
    }
}
