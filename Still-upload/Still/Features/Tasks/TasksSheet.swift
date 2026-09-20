import SwiftUI

/// Today's tasks. Type a title, press return, and it's selected for the next
/// session. Marking done is separate from finishing a session. Details (a due
/// date, a time, a class) are optional and one tap away.
struct TasksSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var newTitle = ""
    @State private var isCapturingVoice = false
    @State private var detailTaskID: UUID?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: StillTheme.Spacing.s) {
                        Image(systemName: "plus")
                            .foregroundStyle(StillTheme.textTertiary)
                            .accessibilityHidden(true)
                        TextField("Add a task", text: $newTitle)
                            .font(StillTypography.body)
                            .submitLabel(.done)
                            .focused($isFieldFocused)
                            .onSubmit(addTask)
                        if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Add", action: addTask)
                                .font(StillTypography.callout.weight(.semibold))
                        } else if appState.canCaptureByVoice {
                            Button {
                                isCapturingVoice = true
                            } label: {
                                Image(systemName: "mic")
                                    .frame(minWidth: StillTheme.minimumTapSize, minHeight: StillTheme.minimumTapSize)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(StillTheme.textSecondary)
                            .accessibilityLabel("Say a task")
                        }
                    }
                    .listRowBackground(StillTheme.surface)
                } footer: {
                    Text("New tasks are chosen for your next session.")
                        .font(StillTypography.caption)
                }

                Section {
                    if appState.todaysTasks.isEmpty {
                        EmptyState(symbol: "checklist", title: "No tasks yet", message: "A task is optional. One is usually enough.")
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(appState.todaysTasks) { task in
                            TaskListRow(
                                task: task,
                                detailLine: detailLine(for: task),
                                isSelected: appState.preferences.selectedTaskID == task.id && !task.isCompleted,
                                onSelect: { toggleSelection(task) },
                                onToggleDone: { appState.setTaskCompleted(task.id, !task.isCompleted) },
                                onDetails: { detailTaskID = task.id }
                            )
                            .listRowBackground(StillTheme.surface)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    appState.deleteTask(task.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Today")
                        .font(StillTypography.footnote.weight(.semibold))
                }
            }
            .scrollContentBackground(.hidden)
            .background(StillTheme.background)
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $detailTaskID) { taskID in
                TaskDetailView(taskID: taskID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        DayTimelineView(showsDoneButton: false)
                    } label: {
                        Label("Day", systemImage: "calendar.day.timeline.left")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isCapturingVoice) {
            VoiceCaptureView()
                .environment(appState)
        }
    }

    /// "Due Friday · Biology · 2 sessions"
    private func detailLine(for task: TaskItem) -> String? {
        var parts: [String] = []
        if let due = appState.dueLine(for: task) { parts.append(due) }
        if let at = task.scheduledAt, !task.isCompleted { parts.append("At \(appState.timeText(at))") }
        if let course = task.homework?.course { parts.append(course) }
        if task.completedSessionCount > 0 {
            parts.append("\(task.completedSessionCount) \(task.completedSessionCount == 1 ? "session" : "sessions")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func addTask() {
        if appState.createTask(title: newTitle) != nil {
            newTitle = ""
        }
    }

    private func toggleSelection(_ task: TaskItem) {
        guard !task.isCompleted else { return }
        let isSelected = appState.preferences.selectedTaskID == task.id
        appState.selectTask(isSelected ? nil : task.id)
    }
}

private struct TaskListRow: View {
    let task: TaskItem
    let detailLine: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleDone: () -> Void
    let onDetails: () -> Void

    var body: some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Button(action: onToggleDone) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(StillTypography.title3)
                    .foregroundStyle(task.isCompleted ? StillTheme.accent : StillTheme.textTertiary)
                    .frame(minWidth: StillTheme.minimumTapSize, minHeight: StillTheme.minimumTapSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark not done" : "Mark done")
            .accessibilityValue(task.title)

            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(StillTypography.body)
                            .strikethrough(task.isCompleted, color: StillTheme.textTertiary)
                            .foregroundStyle(task.isCompleted ? StillTheme.textTertiary : StillTheme.textPrimary)
                        if let detailLine {
                            Text(detailLine)
                                .font(StillTypography.caption)
                                .foregroundStyle(StillTheme.textTertiary)
                        }
                    }
                    Spacer()
                    if isSelected {
                        Text("Next session")
                            .font(StillTypography.caption.weight(.medium))
                            .foregroundStyle(StillTheme.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(task.isCompleted)
            .accessibilityLabel(task.title)
            .accessibilityValue(isSelected ? "Chosen for the next session" : "")
            .accessibilityHint(task.isCompleted ? "" : "Chooses this task for the next session.")

            Button(action: onDetails) {
                Image(systemName: "info.circle")
                    .foregroundStyle(StillTheme.textTertiary)
                    .frame(minWidth: StillTheme.minimumTapSize, minHeight: StillTheme.minimumTapSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details for \(task.title)")
        }
    }
}

#Preview("Tasks") {
    TasksSheet()
        .environment(PreviewSupport.appState(populated: true))
}
