import SwiftUI

/// One day at a glance: tasks due, tasks with a time, finished focus
/// sessions, and (if you allow it) Apple Calendar events. Read-only for the
/// calendar; tasks can be checked off here.
struct DayTimelineView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var dayOffset = 0
    var showsDoneButton = true

    private var day: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }

    var body: some View {
        let items = appState.timeline(for: day)
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    dayHeader

                    if !items.dueToday.isEmpty {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            SectionHeader(title: dayOffset == 0 ? "Due today" : "Due this day")
                            StillCard {
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                                    ForEach(items.dueToday) { item in
                                        TimelineRow(item: item, timeText: nil, onToggle: toggle(item))
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        SectionHeader(title: "Timeline")
                        if items.timed.isEmpty {
                            StillCard {
                                EmptyState(symbol: "calendar", title: "Nothing timed yet",
                                           message: "Give a task a time in its details, or finish a focus session, and it shows up here.")
                            }
                        } else {
                            StillCard {
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                                    ForEach(items.timed) { item in
                                        TimelineRow(item: item, timeText: timeRange(item), onToggle: toggle(item))
                                    }
                                }
                            }
                        }
                    }

                    if appState.container.flags.calendarEvents {
                        calendarControl
                    }
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

    private var dayHeader: some View {
        HStack {
            Button {
                dayOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
            }
            .accessibilityLabel("Previous day")
            Spacer()
            VStack(spacing: 2) {
                Text(dayTitle)
                    .font(StillTypography.title3)
                    .foregroundStyle(StillTheme.textPrimary)
                Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button {
                dayOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
            }
            .accessibilityLabel("Next day")
        }
        .font(StillTypography.body.weight(.semibold))
        .foregroundStyle(StillTheme.textSecondary)
    }

    private var dayTitle: String {
        switch dayOffset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return day.formatted(.dateTime.weekday(.wide))
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
                Button {
                    appState.connectCalendar()
                } label: {
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

    private func timeRange(_ item: TimelineItem) -> String {
        let start = appState.timeText(item.start)
        guard let end = item.end else { return start }
        return "\(start) – \(appState.timeText(end))"
    }

    private func toggle(_ item: TimelineItem) -> (() -> Void)? {
        switch item.kind {
        case .scheduledTask(let id), .dueTask(let id):
            return { appState.setTaskCompleted(id, !item.isDone) }
        case .focusSession, .calendarEvent:
            return nil
        }
    }
}

private struct TimelineRow: View {
    let item: TimelineItem
    let timeText: String?
    let onToggle: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StillTheme.Spacing.s) {
            if let timeText {
                Text(timeText)
                    .font(StillTypography.caption.monospacedDigit())
                    .foregroundStyle(StillTheme.textTertiary)
                    .frame(width: 86, alignment: .leading)
            }
            if let onToggle {
                Button(action: onToggle) {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isDone ? StillTheme.accent : StillTheme.textTertiary)
                        .frame(minWidth: 28, minHeight: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isDone ? "Mark not done" : "Mark done")
                .accessibilityValue(item.title)
            } else {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(minWidth: 28, minHeight: 28)
                    .accessibilityHidden(true)
            }
            Text(item.title)
                .font(StillTypography.callout)
                .strikethrough(item.isDone && onToggle != nil, color: StillTheme.textTertiary)
                .foregroundStyle(item.isDone && onToggle != nil ? StillTheme.textTertiary : StillTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 36)
    }

    private var symbol: String {
        switch item.kind {
        case .focusSession: return "leaf"
        case .calendarEvent: return "calendar"
        case .scheduledTask, .dueTask: return "circle"
        }
    }

    private var tint: Color {
        switch item.kind {
        case .focusSession: return StillTheme.accent
        case .calendarEvent: return StillTheme.calm
        case .scheduledTask, .dueTask: return StillTheme.textTertiary
        }
    }
}

#Preview("Day timeline") {
    NavigationStack {
        DayTimelineView()
    }
    .environment(PreviewSupport.appState(populated: true))
}
