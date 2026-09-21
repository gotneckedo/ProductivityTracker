import SwiftUI

/// A small, immediate task surface: add a thought, choose a next session task,
/// and optionally keep a few checkable steps beneath it.
struct TasksSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var newTitle = ""
    @State private var isCapturingVoice = false
    @State private var detailTaskID: UUID?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            StillScreen(phase: .afternoon) {
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Today")
                                .font(StillTypography.display)
                                .foregroundStyle(StillTheme.textPrimary)
                            Text("Keep the next thing small and visible.")
                                .font(StillTypography.callout)
                                .foregroundStyle(StillTheme.textSecondary)
                        }
                        addBox
                        if appState.todaysTasks.isEmpty {
                            EmptyState(symbol: "checklist", title: "Nothing here yet", message: "A task is optional. One clear thing is usually enough.")
                                .padding(.vertical, StillTheme.Spacing.xl)
                        } else {
                            VStack(spacing: StillTheme.Spacing.s) {
                                ForEach(appState.todaysTasks) { task in
                                    TaskFocusCard(
                                        task: task,
                                        detailLine: detailLine(for: task),
                                        isSelected: appState.preferences.selectedTaskID == task.id && !task.isCompleted,
                                        onSelect: { toggleSelection(task) },
                                        onToggleDone: { appState.setTaskCompleted(task.id, !task.isCompleted) },
                                        onToggleStep: { step in appState.toggleTaskStep(taskID: task.id, stepID: step.id) },
                                        onDetails: { detailTaskID = task.id },
                                        onDelete: { appState.deleteTask(task.id) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $detailTaskID) { TaskDetailView(taskID: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { DayTimelineView(showsDoneButton: false) } label: {
                        Label("Day", systemImage: "calendar.day.timeline.left")
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isCapturingVoice) { VoiceCaptureView().environment(appState) }
    }

    private var addBox: some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Image(systemName: "plus")
                .foregroundStyle(StillTheme.accent)
                .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                .background(StillTheme.accentSoft, in: Circle())
            TextField("Add a task", text: $newTitle)
                .font(StillTypography.body)
                .submitLabel(.done)
                .focused($isFieldFocused)
                .onSubmit(addTask)
            if !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Add", action: addTask)
                    .buttonStyle(QuietSecondaryButtonStyle(foreground: StillTheme.accent))
            } else if appState.canCaptureByVoice {
                Button { isCapturingVoice = true } label: { Image(systemName: "mic") }
                    .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.textSecondary))
                    .accessibilityLabel("Say a task")
            }
        }
        .padding(StillTheme.Spacing.s)
        .stillGlass(radius: StillTheme.Radius.medium, phase: .afternoon)
    }

    /// "Due Friday · Biology · 2 sessions"
    private func detailLine(for task: TaskItem) -> String? {
        var parts: [String] = []
        if let due = appState.dueLine(for: task) { parts.append(due) }
        if let at = task.scheduledAt, !task.isCompleted { parts.append("At \(appState.timeText(at))") }
        if let course = task.homework?.course { parts.append(course) }
        if task.completedSessionCount > 0 { parts.append("\(task.completedSessionCount) \(task.completedSessionCount == 1 ? "session" : "sessions")") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func addTask() {
        if appState.createTask(title: newTitle) != nil { newTitle = "" }
    }

    private func toggleSelection(_ task: TaskItem) {
        guard !task.isCompleted else { return }
        appState.selectTask(appState.preferences.selectedTaskID == task.id ? nil : task.id)
    }
}

private struct TaskFocusCard: View {
    let task: TaskItem
    let detailLine: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleDone: () -> Void
    let onToggleStep: (TaskStep) -> Void
    let onDetails: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
                Button(action: onToggleDone) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(StillTypography.title3)
                        .foregroundStyle(task.isCompleted ? StillTheme.accent : StillTheme.textTertiary)
                        .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Mark not done" : "Mark done")

                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Circle().fill(subjectTint).frame(width: 8, height: 8)
                            Text(task.title)
                                .font(StillTypography.bodyEmphasis)
                                .strikethrough(task.isCompleted, color: StillTheme.textTertiary)
                                .foregroundStyle(task.isCompleted ? StillTheme.textTertiary : StillTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        if let detailLine {
                            Text(detailLine)
                                .font(StillTypography.caption)
                                .foregroundStyle(StillTheme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(task.isCompleted)
                Spacer(minLength: 0)
                Menu {
                    Button("Details", action: onDetails)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(StillTheme.textTertiary)
                        .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                }
            }
            if isSelected {
                Text("Next focus")
                    .font(StillTypography.caption)
                    .foregroundStyle(StillTheme.accent)
                    .padding(.leading, StillTheme.minimumTapSize + StillTheme.Spacing.s)
            }
            if !task.steps.isEmpty {
                Divider().opacity(0.45)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(task.steps) { step in
                        Button { onToggleStep(step) } label: {
                            HStack(spacing: StillTheme.Spacing.xs) {
                                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(step.isCompleted ? StillTheme.accent : StillTheme.textTertiary)
                                Text(step.title)
                                    .font(StillTypography.footnote)
                                    .strikethrough(step.isCompleted, color: StillTheme.textTertiary)
                                    .foregroundStyle(step.isCompleted ? StillTheme.textTertiary : StillTheme.textPrimary)
                                Spacer()
                            }
                            .frame(minHeight: 28)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, StillTheme.minimumTapSize + StillTheme.Spacing.s)
            }
        }
        .padding(StillTheme.Spacing.s)
        .stillGlass(radius: StillTheme.Radius.medium, phase: .afternoon)
        .accessibilityElement(children: .contain)
    }

    private var subjectTint: Color {
        let key = task.homework?.course ?? task.title
        let value = key.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return [Color(hex: 0x6E92C8), Color(hex: 0xA77BC2), Color(hex: 0xD99163), Color(hex: 0x5F9A74)][value % 4]
    }
}

#Preview("Tasks") {
    TasksSheet()
        .environment(PreviewSupport.appState(populated: true))
}
