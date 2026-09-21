import SwiftUI

/// A gentle day planner: the week gives context, habits stay lightweight, timed
/// work has duration, and untimed tasks land in a clear part of the day.
struct DayTimelineView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var dayOffset = 0
    var showsDoneButton = true

    private var day: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }

    var body: some View {
        let timeline = appState.timeline(for: day)
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    weekStrip

                    let habits = appState.habits(on: day)
                    if !habits.isEmpty { habitBubbles(habits) }

                    timedSection(timeline.timed)

                    ForEach(timeline.untimedGroups) { group in
                        untimedSection(group)
                    }

                    if appState.container.flags.calendarEvents { calendarControl }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationTitle("Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            HStack {
                Button { dayOffset -= 7 } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                }
                .accessibilityLabel("Previous week")
                Spacer()
                VStack(spacing: 2) {
                    Text(dayTitle)
                        .font(StillTypography.title3)
                        .foregroundStyle(StillTheme.textPrimary)
                    Text(day.formatted(.dateTime.month(.wide).year()))
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                }
                Spacer()
                Button { dayOffset += 7 } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                }
                .accessibilityLabel("Next week")
            }

            HStack(spacing: 4) {
                ForEach(-3...3, id: \.self) { delta in
                    let offset = dayOffset + delta
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                    let selected = delta == 0
                    Button { dayOffset = offset } label: {
                        VStack(spacing: 5) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(StillTypography.caption)
                            Text(date.formatted(.dateTime.day()))
                                .font(StillTypography.bodyEmphasis.monospacedDigit())
                            HStack(spacing: 2) {
                                let colors = dotColors(on: date)
                                if colors.isEmpty {
                                    Circle().fill(Color.clear).frame(width: 5, height: 5)
                                } else {
                                    ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                                        Circle().fill(color).frame(width: 5, height: 5)
                                    }
                                }
                            }
                            .frame(height: 5)
                        }
                        .foregroundStyle(selected ? StillTheme.textPrimary : StillTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 67)
                        .background(selected ? .white.opacity(0.46) : .clear, in: Capsule())
                        .overlay {
                            if selected {
                                Capsule().strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month().day()))
                    .accessibilityValue(selected ? "Selected" : "")
                }
            }
        }
    }

    private func habitBubbles(_ habits: [HabitDay]) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Small habits", detail: "Tap a bubble for this day.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StillTheme.Spacing.s) {
                    ForEach(habits) { habit in
                        Button { appState.toggleHabit(habit.id, on: day) } label: {
                            VStack(spacing: 7) {
                                ZStack {
                                    Circle()
                                        .fill(habit.isDoneToday ? StillTheme.accent : .white.opacity(0.34))
                                    Circle()
                                        .strokeBorder(habit.isDoneToday ? StillTheme.accent : Color.white.opacity(0.72), lineWidth: 1)
                                    Image(systemName: habit.isDoneToday ? "checkmark" : "circle.dashed")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(habit.isDoneToday ? StillTheme.onAccent : StillTheme.textSecondary)
                                }
                                .frame(width: 54, height: 54)
                                Text(habit.habit.title)
                                    .font(StillTypography.caption)
                                    .foregroundStyle(StillTheme.textSecondary)
                                    .lineLimit(1)
                                    .frame(width: 76)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(habit.isDoneToday ? "Done" : "Not done")
                    }
                }
            }
        }
    }

    private func timedSection(_ items: [TimelineItem]) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Timeline", detail: "Capsule height follows duration.")
            if items.isEmpty {
                StillCard {
                    EmptyState(symbol: "calendar", title: "Nothing timed yet",
                               message: "Give a task a time in its details, or finish a focus session, and it shows up here.")
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        TimedCapsule(
                            item: item,
                            timeText: timeRange(item),
                            onToggle: toggle(item)
                        )
                    }
                }
            }
        }
    }

    private func untimedSection(_ group: TimelineUntimedGroup) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: group.period.displayName)
            StillCard {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                    ForEach(group.items) { item in
                        UntimedTaskRow(item: item, onToggle: toggle(item))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var calendarControl: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Calendar", detail: "Events are read from Apple Calendar on this device. Still never changes them.")
            switch appState.calendarAccess {
            case .granted:
                StillCard {
                    Toggle("Show calendar events", isOn: Binding(
                        get: { appState.preferences.showsCalendarEvents },
                        set: { appState.setShowsCalendarEvents($0) }
                    ))
                    .font(StillTypography.body)
                }
            case .notDetermined:
                Button { appState.connectCalendar() } label: {
                    Label("Show my calendar", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(QuietSecondaryButtonStyle())
            case .denied:
                QuietNote(text: "Calendar access is off. Turn it on in Settings → Still → Calendars.", symbol: "calendar")
            case .unavailable:
                EmptyView()
            }
        }
    }

    private var dayTitle: String {
        switch dayOffset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return day.formatted(.dateTime.weekday(.wide).day())
        }
    }

    private func dotColors(on date: Date) -> [Color] {
        let timeline = appState.timeline(for: date)
        let colors = (timeline.timed + timeline.dueToday).compactMap { item in
            item.subject.map { Color(hex: $0.color.hex) }
        }
        return colors.isEmpty && (!timeline.timed.isEmpty || !timeline.dueToday.isEmpty)
            ? [StillTheme.calm]
            : Array(colors.prefix(3))
    }

    private func timeRange(_ item: TimelineItem) -> String {
        let start = appState.timeText(item.start)
        guard let end = item.end else { return start }
        return "\(start) – \(appState.timeText(end))"
    }

    private func toggle(_ item: TimelineItem) -> (() -> Void)? {
        switch item.kind {
        case .scheduledTask(let id), .dueTask(let id):
            return { appState.setTaskCompleted(id, on: day, !item.isDone) }
        case .focusSession, .calendarEvent:
            return nil
        }
    }
}

private struct TimedCapsule: View {
    let item: TimelineItem
    let timeText: String
    let onToggle: (() -> Void)?

    private var tint: Color {
        if let subject = item.subject { return Color(hex: subject.color.hex) }
        switch item.kind {
        case .focusSession: return StillTheme.accent
        case .calendarEvent: return StillTheme.calm
        case .scheduledTask, .dueTask: return StillTheme.textTertiary
        }
    }

    /// One point per minute keeps relative durations immediately legible while
    /// retaining a tappable minimum for very short items.
    private var capsuleHeight: CGFloat {
        max(44, min(180, CGFloat(item.duration / 60)))
    }

    var body: some View {
        HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
            VStack(spacing: 0) {
                Circle().fill(tint).frame(width: 10, height: 10)
                Rectangle().fill(tint.opacity(0.32)).frame(width: 2)
            }
            .frame(width: 16, height: capsuleHeight + 12)

            HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
                if let onToggle {
                    Button(action: onToggle) {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .font(StillTypography.title3)
                            .foregroundStyle(tint)
                            .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isDone ? "Mark not done" : "Mark done")
                } else {
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                        .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(timeText)
                        .font(StillTypography.caption.monospacedDigit())
                        .foregroundStyle(StillTheme.textSecondary)
                    Text(item.title)
                        .font(StillTypography.bodyEmphasis)
                        .strikethrough(item.isDone && onToggle != nil)
                        .foregroundStyle(item.isDone && onToggle != nil ? StillTheme.textTertiary : StillTheme.textPrimary)
                    if let subject = item.subject {
                        Text(subject.name)
                            .font(StillTypography.caption)
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, StillTheme.Spacing.s)
            .frame(height: capsuleHeight, alignment: .top)
            .background(tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(tint.opacity(0.72), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var symbol: String {
        switch item.kind {
        case .focusSession: return "leaf"
        case .calendarEvent: return "calendar"
        case .scheduledTask, .dueTask: return "circle"
        }
    }
}

private struct UntimedTaskRow: View {
    let item: TimelineItem
    let onToggle: (() -> Void)?

    private var tint: Color {
        item.subject.map { Color(hex: $0.color.hex) } ?? StillTheme.textTertiary
    }

    var body: some View {
        HStack(spacing: StillTheme.Spacing.s) {
            if let onToggle {
                Button(action: onToggle) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(tint)
                        .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                }
                .buttonStyle(.plain)
            }
            Circle().fill(tint).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(StillTypography.callout)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? StillTheme.textTertiary : StillTheme.textPrimary)
                if let subject = item.subject {
                    Text(subject.name)
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textSecondary)
                }
            }
            Spacer()
        }
        .frame(minHeight: StillTheme.minimumTapSize)
    }
}

#Preview("Day timeline") {
    NavigationStack { DayTimelineView() }
        .environment(PreviewSupport.appState(populated: true))
}
