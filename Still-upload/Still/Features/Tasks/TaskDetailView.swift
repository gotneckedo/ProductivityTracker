import SwiftUI

/// Rich task editing stays separate from one-line capture. The page uses a
/// familiar notebook treatment, softened inside Still's glass system.
struct TaskDetailView: View {
    let taskID: UUID

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasDue = false
    @State private var dueAt = Date()
    @State private var hasSchedule = false
    @State private var scheduledAt = Date()
    @State private var durationMinutes = 30
    @State private var dayPeriod = TaskDayPeriod.anytime
    @State private var subjectName = ""
    @State private var subjectColor = SubjectColor.sage
    @State private var repeatRule = TaskRepeatRule.once
    @State private var newStep = ""
    @State private var hasLoaded = false

    var body: some View {
        StillScreen {
            ScrollView {
                if let task = appState.task(taskID) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                        notebook(task: task)

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
        .onChange(of: durationMinutes) { _, _ in saveDetails() }
        .onChange(of: dayPeriod) { _, _ in saveDetails() }
        .onChange(of: subjectColor) { _, _ in saveDetails() }
        .onChange(of: repeatRule) { _, _ in saveDetails() }
        .onDisappear {
            saveDetails()
            if let task = appState.task(taskID), TaskItem.normalizedTitle(title) != task.title {
                appState.renameTask(taskID, to: title)
            }
        }
    }

    private func notebook(task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Task", text: $title, axis: .vertical)
                .font(StillTypography.title)
                .foregroundStyle(StillTheme.textPrimary)
                .lineLimit(1...3)
                .submitLabel(.done)
                .onSubmit { appState.renameTask(taskID, to: title) }
                .padding(.leading, 34)
                .padding(.horizontal, StillTheme.Spacing.m)
                .padding(.vertical, StillTheme.Spacing.l)

            NotebookSection(label: "Subject", tint: Color(hex: subjectColor.hex)) {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                    TextField("Class or subject (optional)", text: $subjectName)
                        .font(StillTypography.body)
                        .submitLabel(.done)
                        .onSubmit(saveDetails)
                    HStack(spacing: 10) {
                        ForEach(SubjectColor.allCases) { color in
                            Button {
                                subjectColor = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color.hex))
                                    .frame(width: 27, height: 27)
                                    .overlay {
                                        if color == subjectColor {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(color.displayName)
                            .accessibilityValue(color == subjectColor ? "Selected" : "")
                        }
                    }
                }
            }

            NotebookSection(label: "When", tint: StillTheme.calm) {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                    Toggle("Due date", isOn: $hasDue)
                    if hasDue {
                        DatePicker("Due", selection: $dueAt, displayedComponents: .date)
                    }
                    Toggle("Time to do it", isOn: $hasSchedule)
                    if hasSchedule {
                        DatePicker("At", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                        Stepper("Duration · \(durationMinutes) min", value: $durationMinutes, in: 5...720, step: 5)
                    } else {
                        Picker("Part of day", selection: $dayPeriod) {
                            ForEach(TaskDayPeriod.allCases) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .font(StillTypography.callout)
            }

            NotebookSection(label: "Repeat", tint: StillTheme.highlight) {
                RepeatRulePicker(rule: $repeatRule, anchor: hasSchedule ? scheduledAt : (hasDue ? dueAt : Date()))
            }

            NotebookSection(label: "Steps", tint: StillTheme.warm) {
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
        .background {
            NotebookPaper()
        }
        .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous)
                .strokeBorder(Color.white.opacity(0.72), lineWidth: StillTheme.Stroke.hairline)
        }
        .shadow(color: StillTheme.Shadow.color, radius: StillTheme.Shadow.radius, y: StillTheme.Shadow.y)
    }

    private func load() {
        guard !hasLoaded, let task = appState.task(taskID) else { return }
        title = task.title
        hasDue = task.dueAt != nil
        dueAt = task.dueAt ?? Self.defaultDue()
        hasSchedule = task.scheduledAt != nil
        scheduledAt = task.scheduledAt ?? Self.defaultSchedule()
        durationMinutes = Int((task.plannedDuration ?? 30 * 60) / 60)
        dayPeriod = task.dayPeriod
        subjectName = task.subject?.name ?? ""
        subjectColor = task.subject?.color ?? .sage
        repeatRule = task.repeatRule
        hasLoaded = true
    }

    private func saveDetails() {
        guard hasLoaded else { return }
        let subject = Subject.normalizedName(subjectName).map { Subject(name: $0, color: subjectColor) }
        appState.updateTaskDetails(
            taskID,
            dueAt: hasDue ? dueAt : nil,
            scheduledAt: hasSchedule ? scheduledAt : nil,
            subject: subject,
            plannedDuration: hasSchedule ? Double(durationMinutes * 60) : nil,
            dayPeriod: dayPeriod,
            repeatRule: repeatRule
        )
    }

    private func addStep() {
        if appState.addTaskStep(taskID: taskID, title: newStep) { newStep = "" }
    }

    private static func defaultDue() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private static func defaultSchedule() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextHour)
        return calendar.date(from: components) ?? nextHour
    }
}

private struct NotebookPaper: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.white.opacity(0.64)
                Canvas { context, size in
                    let rule = Color(hex: 0x91B8D8, opacity: 0.24)
                    for y in stride(from: 54.0, through: size.height, by: 32) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(rule), lineWidth: 1)
                    }
                    var margin = Path()
                    margin.move(to: CGPoint(x: 31, y: 0))
                    margin.addLine(to: CGPoint(x: 31, y: size.height))
                    context.stroke(margin, with: .color(Color(hex: 0xD9A0AA, opacity: 0.38)), lineWidth: 1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct NotebookSection<Content: View>: View {
    let label: String
    let tint: Color
    let content: Content

    init(label: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.label = label
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            Text(label)
                .font(StillTypography.caption.weight(.semibold))
                .foregroundStyle(StillTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.45), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .rotationEffect(.degrees(-1))
            content
                .padding(.leading, 34)
        }
        .padding(.horizontal, StillTheme.Spacing.m)
        .padding(.vertical, StillTheme.Spacing.m)
    }
}

struct RepeatRulePicker: View {
    @Binding var rule: TaskRepeatRule
    let anchor: Date

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            HStack(spacing: 5) {
                ForEach(TaskRepeatFrequency.allCases) { frequency in
                    Button {
                        rule.frequency = frequency
                        if frequency == .once { rule.interval = 1; rule.weekdays = [] }
                        if frequency == .weekly, rule.weekdays.isEmpty {
                            rule.weekdays = [Calendar.current.component(.weekday, from: anchor)]
                        }
                    } label: {
                        Text(frequency.displayName)
                            .font(StillTypography.caption)
                            .foregroundStyle(rule.frequency == frequency ? StillTheme.onAccent : StillTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 34)
                            .background(rule.frequency == frequency ? StillTheme.accent : .white.opacity(0.28), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            if rule.frequency != .once {
                Stepper(value: $rule.interval, in: 1...99) {
                    Text(intervalLine)
                        .font(StillTypography.callout)
                }
            }
            if rule.frequency == .weekly {
                HStack(spacing: 5) {
                    ForEach(1...7, id: \.self) { weekday in
                        Button {
                            if rule.weekdays.contains(weekday), rule.weekdays.count > 1 {
                                rule.weekdays.remove(weekday)
                            } else {
                                rule.weekdays.insert(weekday)
                            }
                        } label: {
                            Text(Self.weekdaySymbols[weekday - 1])
                                .font(StillTypography.caption.weight(.semibold))
                                .foregroundStyle(rule.weekdays.contains(weekday) ? StillTheme.onAccent : StillTheme.textSecondary)
                                .frame(width: 34, height: 34)
                                .background(rule.weekdays.contains(weekday) ? StillTheme.accent : .white.opacity(0.28), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var intervalLine: String {
        let unit: String
        switch rule.frequency {
        case .daily: unit = rule.interval == 1 ? "day" : "days"
        case .weekly: unit = rule.interval == 1 ? "week" : "weeks"
        case .monthly: unit = rule.interval == 1 ? "month" : "months"
        case .once: unit = "time"
        }
        return "Every \(rule.interval) \(unit)"
    }

    private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
}

#Preview("Task detail") {
    let state = PreviewSupport.appState(populated: true)
    return NavigationStack {
        if let task = state.todaysTasks.first { TaskDetailView(taskID: task.id) }
    }
    .environment(state)
}
