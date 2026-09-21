import SwiftUI

/// Completion is a warm pause, not a scoreboard: one acknowledgement, honest
/// progress from the stored session, and three finite ways to reset.
struct SessionCompleteView: View {
    let sessionID: UUID
    @Environment(AppState.self) private var appState
    @State private var taskMarkedDone = false

    var body: some View {
        let session = appState.session(sessionID)
        let suggestions = appState.suggestions(for: sessionID)
        StillScreen(phase: .dusk) {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    completionHero(session: session)
                    metrics(session: session)

                    if let task = appState.task(session?.taskID) {
                        taskLine(task)
                    }

                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        Text("What would feel good next?")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(Array(suggestions.activities.enumerated()), id: \.element.id) { rank, activity in
                            Button {
                                appState.openSuggestion(activity, rank: rank, sessionID: sessionID)
                            } label: {
                                CompletionActivityCard(activity: activity)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: StillTheme.Spacing.s) {
                        Button("Browse shelf") { appState.openShelfFromCompletion() }
                            .buttonStyle(QuietSecondaryButtonStyle())
                        Button("Back to room") { appState.returnToFocusFromCompletion() }
                            .buttonStyle(QuietTextButtonStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.xl)
            }
        }
    }

    private func completionHero(session: FocusSession?) -> some View {
        ZStack(alignment: .bottomLeading) {
            Circle()
                .fill(RadialGradient(colors: [StillDayPhase.dusk.roomHalo, .clear], center: .center, startRadius: 0, endRadius: 170))
                .blur(radius: 18)
                .frame(width: 250, height: 170)
                .offset(x: 40, y: -8)
            VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                Text("Nice work.")
                    .font(StillTypography.hero)
                    .foregroundStyle(StillTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("You gave \(focusedAmount(session)) to what mattered.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                Text(usualLine)
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textTertiary)
            }
            .padding(.top, StillTheme.Spacing.xxl)
        }
        .stillEntrance()
    }

    private func metrics(session: FocusSession?) -> some View {
        let duration = session?.completedFocusDuration ?? 0
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StillTheme.Spacing.s) {
            CompletionMetric(value: DurationFormatter.short(duration), label: "this session")
            CompletionMetric(value: "\(appState.stats.todayFocus == 0 ? 1 : appState.stats.completedSessions)", label: "sessions kept")
            CompletionMetric(value: DurationFormatter.short(appState.stats.weekFocus), label: "this week")
            CompletionMetric(value: appState.stats.currentStreak == 0 ? "—" : "\(appState.stats.currentStreak)", label: "day rhythm")
        }
        .padding(StillTheme.Spacing.m)
        .stillGlass(radius: StillTheme.Radius.medium, phase: .dusk)
        .accessibilityElement(children: .contain)
    }

    private func taskLine(_ task: TaskItem) -> some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Image(systemName: task.isCompleted || taskMarkedDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted || taskMarkedDone ? StillTheme.accent : StillTheme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                    .lineLimit(2)
                Text(task.isCompleted || taskMarkedDone ? "Marked complete" : "Focused on just now")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
            }
            Spacer(minLength: StillTheme.Spacing.xs)
            if !task.isCompleted && !taskMarkedDone {
                Button("Mark done") {
                    appState.setTaskCompleted(task.id, true)
                    taskMarkedDone = true
                }
                .buttonStyle(QuietSecondaryButtonStyle())
            }
        }
        .padding(StillTheme.Spacing.s)
        .stillGlass(radius: StillTheme.Radius.medium, phase: .dusk)
    }

    private var usualLine: String {
        let sessions = appState.stats.completedSessions
        guard sessions > 1 else { return "A small ritual still counts." }
        let average = DurationFormatter.short(appState.stats.averageSessionDuration)
        return "Your usual session is about \(average)."
    }

    private func focusedAmount(_ session: FocusSession?) -> String {
        let seconds = session?.completedFocusDuration ?? 0
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 { return DurationFormatter.short(seconds) }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

private struct CompletionMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(StillTypography.metric)
                .foregroundStyle(StillTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }
}

private struct CompletionActivityCard: View {
    let activity: BreakActivity

    var body: some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Image(systemName: activity.symbolName)
                .font(StillTypography.title3)
                .foregroundStyle(StillTheme.categoryTint(activity.category))
                .frame(width: 34, height: 34)
                .background(StillTheme.categorySoftTint(activity.category), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                Text("\(activity.estimatedMinutes) min · \(activity.summary)")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: StillTheme.Spacing.xs)
            Image(systemName: "arrow.up.right")
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textTertiary)
        }
        .padding(StillTheme.Spacing.s)
        .stillGlass(radius: StillTheme.Radius.medium, phase: .dusk)
        .contentShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.name), about \(activity.estimatedMinutes) minutes. \(activity.summary)")
    }
}

#Preview("Session complete") {
    let preview = PreviewSupport.completedSession()
    return SessionCompleteView(sessionID: preview.sessionID)
        .environment(preview.state)
}
