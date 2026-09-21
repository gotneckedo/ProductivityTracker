import SwiftUI

/// Optional details for one task: a due date, a time to do it, and a class
/// name for homework. Changes save as you make them.
struct TaskDetailView: View {
    let taskID: UUID

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasDue = false
    @State private var dueAt = Date()
    @State private var hasSchedule = false
    @State private var scheduledAt = Date()
    @State private var course = ""
    @State private var newStep = ""
    @State private var hasLoaded = false

    var body: some View {
        StillScreen {
            ScrollView {
                if let task = appState.task(taskID) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                        StillCard {
                            VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                                Text("Task")
                                    .font(StillTypography.caption)
                                    .foregroundStyle(StillTheme.textTertiary)
                                TextField("Task", text: $title, axis: .vertical)
                                    .font(StillTypography.body)
                                    .lineLimit(1...3)
                                    .submitLabel(.done)
                                    .onSubmit { appState.renameTask(taskID, to: title) }
                            }
                        }

                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            SectionHeader(title: "When", detail: "Both are optional. Scheduled tasks show on the day timeline.")
                            StillCard {
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                                    Toggle("Due date", isOn: $hasDue)
                                        .font(StillTypography.body)
                                    if hasDue {
                                        DatePicker("Due", selection: $dueAt, displayedComponents: .date)
                                            .font(StillTypography.callout)
                                    }
                                    Divider()
                                    Toggle("Time to do it", isOn: $hasSchedule)
                                        .font(StillTypography.body)
                                    if hasSchedule {
                                        DatePicker("At", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                                            .font(StillTypography.callout)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            SectionHeader(title: "Homework", detail: "Add a class name to group schoolwork.")
                            StillCard {
                                TextField("Class (optional)", text: $course)
                                    .font(StillTypography.body)
                                    .submitLabel(.done)
                                    .onSubmit(saveDetails)
                            }
                        }

                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            SectionHeader(title: "Steps", detail: "Optional small actions for the next focus session.")
                            StillCard {
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                                    ForEach(task.steps) { step in
                                        HStack(spacing: StillTheme.Spacing.s) {
                                            Button { appState.toggleTaskStep(taskID: taskID, stepID: step.id) } label: {
                                                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(step.isCompleted ? StillTheme.accent : StillTheme.textTertiary)
                                                    .frame(width: 28, height: 28)
                                            }
                                            .buttonStyle(.plain)
                                            Text(step.title)
                                                .font(StillTypography.callout)
                                                .strikethrough(step.isCompleted, color: StillTheme.textTertiary)
                                                .foregroundStyle(step.isCompleted ? StillTheme.textTertiary : StillTheme.textPrimary)
                                            Spacer()
                                            Button(role: .destructive) { appState.deleteTaskStep(taskID: taskID, stepID: step.id) } label: {
                                                Image(systemName: "xmark")
                                            }
                                            .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.textTertiary))
                                        }
                                    }
                                    HStack(spacing: StillTheme.Spacing.s) {
                                        TextField("Add a step", text: $newStep)
                                            .font(StillTypography.callout)
                                            .submitLabel(.done)
                                            .onSubmit(addStep)
                                        Button("Add", action: addStep)
                                            .buttonStyle(QuietSecondaryButtonStyle(foreground: StillTheme.accent))
                                            .disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                            }
                        }

                        Button(role: .destructive) {
                            appState.deleteTask(taskID)
                            dismiss()
                        } label: {
                            Label("Delete task", systemImage: "trash")
                        }
                        .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.attention))
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                } else {
                    EmptyState(symbol: "checklist", title: "Task removed", message: "This task isn't here anymore.")
                }
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: hasDue) { _, _ in saveDetails() }
        .onChange(of: dueAt) { _, _ in saveDetails() }
        .onChange(of: hasSchedule) { _, _ in saveDetails() }
        .onChange(of: scheduledAt) { _, _ in saveDetails() }
        .onDisappear {
            saveDetails()
            if let task = appState.task(taskID), TaskItem.normalizedTitle(title) != task.title {
                appState.renameTask(taskID, to: title)
            }
        }
    }

    private func load() {
        guard !hasLoaded, let task = appState.task(taskID) else { return }
        title = task.title
        hasDue = task.dueAt != nil
        dueAt = task.dueAt ?? Self.defaultDue()
        hasSchedule = task.scheduledAt != nil
        scheduledAt = task.scheduledAt ?? Self.defaultSchedule()
        course = task.homework?.course ?? ""
        hasLoaded = true
    }

    private func saveDetails() {
        guard hasLoaded else { return }
        appState.updateTaskDetails(
            taskID,
            dueAt: hasDue ? dueAt : nil,
            scheduledAt: hasSchedule ? scheduledAt : nil,
            course: course
        )
    }

    private func addStep() {
        if appState.addTaskStep(taskID: taskID, title: newStep) {
            newStep = ""
        }
    }

    /// Tomorrow, so a new due date isn't instantly "today".
    private static func defaultDue() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    /// The next full hour.
    private static func defaultSchedule() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextHour)
        return calendar.date(from: components) ?? nextHour
    }
}
