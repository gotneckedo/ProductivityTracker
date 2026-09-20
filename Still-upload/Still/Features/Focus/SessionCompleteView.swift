import SwiftUI

/// The session-complete moment: a calm acknowledgement and exactly three
/// finite things to do instead. No confetti, no streak pressure.
struct SessionCompleteView: View {
    let sessionID: UUID
    @Environment(AppState.self) private var appState
    @State private var taskMarkedDone = false

    var body: some View {
        let session = appState.session(sessionID)
        let suggestions = appState.suggestions(for: sessionID)
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    CalmPlantCanvas(stage: .full)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
                        .accessibilityHidden(true)
                        .stillEntrance()

                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text(focusedAmount(session))
                            .font(StillTypography.display)
                            .foregroundStyle(StillTheme.textPrimary)
                        Text("focused")
                            .font(StillTypography.title3)
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    .stillEntrance(delay: 0.05)

                    if let task = appState.task(session?.taskID) {
                        taskLine(task)
                    }

                    if let unlocked = appState.newlyUnlockedScenes.first {
                        QuietNote(text: "\(unlocked.name) is open now. You'll find it in Me.", symbol: "leaf")
                    }

                    PixelDivider()

                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        Text(suggestions.headline)
                            .font(StillTypography.title3)
                            .foregroundStyle(StillTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(Array(suggestions.activities.enumerated()), id: \.element.id) { rank, activity in
                            Button {
                                appState.openSuggestion(activity, rank: rank, sessionID: sessionID)
                            } label: {
                                ActivityTile(activity: activity, style: .suggestion)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .stillEntrance(delay: 0.15)

                    VStack(spacing: StillTheme.Spacing.xs) {
                        Button("See all activities") {
                            appState.openShelfFromCompletion()
                        }
                        .buttonStyle(QuietSecondaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        Button("Return to Focus") {
                            appState.returnToFocusFromCompletion()
                        }
                        .buttonStyle(QuietTextButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.xl)
            }
        }
    }

    private func taskLine(_ task: TaskItem) -> some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Text(task.title)
                .font(StillTypography.bodyEmphasis)
                .foregroundStyle(StillTheme.textPrimary)
                .lineLimit(2)
            Spacer(minLength: StillTheme.Spacing.xs)
            if task.isCompleted || taskMarkedDone {
                Label("Done", systemImage: "checkmark")
                    .font(StillTypography.footnote.weight(.medium))
                    .foregroundStyle(StillTheme.accent)
            } else {
                Button("Mark done") {
                    appState.setTaskCompleted(task.id, true)
                    taskMarkedDone = true
                }
                .buttonStyle(QuietSecondaryButtonStyle())
                .accessibilityHint("Marks this task done. Separate from finishing the session.")
            }
        }
    }

    private func focusedAmount(_ session: FocusSession?) -> String {
        let seconds = session?.completedFocusDuration ?? 0
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 { return DurationFormatter.short(seconds) }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

#Preview("Session complete") {
    let preview = PreviewSupport.completedSession()
    return SessionCompleteView(sessionID: preview.sessionID)
        .environment(preview.state)
}
