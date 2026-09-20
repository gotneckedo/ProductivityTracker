import SwiftUI

/// Today's tasks. Type a title, press return, and it's selected for the next
/// session. Marking done is separate from finishing a session.
struct TasksSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var newTitle = ""
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
                                isSelected: appState.preferences.selectedTaskID == task.id && !task.isCompleted,
                                onSelect: { toggleSelection(task) },
                                onToggleDone: { appState.setTaskCompleted(task.id, !task.isCompleted) }
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleDone: () -> Void

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
                        if task.completedSessionCount > 0 {
                            Text("\(task.completedSessionCount) \(task.completedSessionCount == 1 ? "session" : "sessions")")
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
        }
    }
}

#Preview("Tasks") {
    TasksSheet()
        .environment(PreviewSupport.appState(populated: true))
}
