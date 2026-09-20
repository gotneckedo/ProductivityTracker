import Foundation

/// Fast, typed task capture. No projects, tags, or due dates in V1.
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

    func rename(id: UUID, to raw: String) {
        guard let title = TaskItem.normalizedTitle(raw), var task = tasks.task(id: id) else { return }
        task.title = title
        persist(task)
    }

    /// Marking done is separate from finishing a focus session.
    func setCompleted(id: UUID, _ completed: Bool) {
        guard var task = tasks.task(id: id) else { return }
        task.completedAt = completed ? (task.completedAt ?? clock.now) : nil
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
        let open = all.filter { !$0.isCompleted }.sorted { $0.createdAt < $1.createdAt }
        let doneToday = all
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
