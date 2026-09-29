import SwiftUI

/// Completion is a warm pause, not a scoreboard: one acknowledgement, honest
/// progress from the stored session, and three finite ways to reset.
struct SessionCompleteView: View {
    let sessionID: UUID
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taskMarkedDone = false
    @State private var unlockIsVisible = false

    var body: some View {
        let session = appState.session(sessionID)
        let suggestions = appState.suggestions(for: sessionID)
        StillScreen(phase: .dusk) {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    completionHero(session: session)
                    transitionRitual

                    if FirstRunExperience.offersPersonalization(
                        completedSessions: appState.completedSessionCount,
                        goal: appState.preferences.onboardingGoal,
                        breakAppeal: appState.preferences.breakAppeal
                    ) {
                        firstSessionPreferences
                    }

                    metrics(session: session)

                    if !appState.newlyUnlockedRoomObjects.isEmpty {
                        newUnlocks(appState.newlyUnlockedRoomObjects)
                    }

                    if let task = appState.task(session?.taskID) {
                        taskLine(task)
                    }

                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        Text("What's next?")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        MatteActivityCanvas(tint: StillTheme.warmSoft, phase: .dusk) {
                            VStack(spacing: 0) {
                                ForEach(Array(suggestions.activities.enumerated()), id: \.element.id) { rank, activity in
                                    Button {
                                        appState.openSuggestion(activity, rank: rank, sessionID: sessionID)
                                    } label: {
                                        CompletionActivityCard(activity: activity)
                                    }
                                    .buttonStyle(StillRowButtonStyle())
                                    if rank < suggestions.activities.count - 1 {
                                        InsetRowDivider(leading: 42, phase: .dusk)
                                    }
                                }
                            }
                            .padding(.horizontal, StillTheme.Spacing.s)
                            .padding(.vertical, StillTheme.Spacing.xs)
                        }
                    }

                    HStack(spacing: StillTheme.Spacing.s) {
                        Button(Copy.Completion.browseShelf) { appState.openShelfFromCompletion() }
                            .buttonStyle(QuietSecondaryButtonStyle())
                        Button(Copy.Completion.backToRoom) { appState.returnToFocusFromCompletion() }
                            .buttonStyle(QuietTextButtonStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.xl)
            }
            .stillScrollableViewport(reservingFloatingTabBar: false)
        }
        .onAppear {
            StillInteractionFeedback.fire(.focusCompleted, preferences: appState.preferences)
        }
    }

    private func completionHero(session: FocusSession?) -> some View {
        let scene = appState.scene(session?.sceneID ?? appState.currentPreset.sceneID)
        return VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            RoomHeroView(
                sceneName: scene.name,
                sceneID: scene.id,
                catCoat: appState.preferences.catCoat,
                catName: appState.catName,
                catState: .complete,
                sessionState: .justFinished,
                phase: .dusk,
                plantStage: appState.plantStage,
                bookCount: 2 + appState.books.count,
                doodle: appState.doodles.max { $0.updatedAt < $1.updatedAt }?.doodle,
                placedObjects: appState.placedRoomObjects(in: scene.id),
                showsControls: false
            )
            .aspectRatio(RoomHeroView.artworkAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .clipped()

            VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                Text(Copy.Completion.title)
                    .font(StillTypography.hero)
                    .foregroundStyle(StillTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(Copy.Completion.focused(focusedAmount(session)))
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                Text(usualLine)
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textTertiary)
                if let catLine = catCompletionLine(session) {
                    Text(catLine)
                        .font(StillTypography.footnote.weight(.semibold))
                        .foregroundStyle(StillDayPhase.dusk.accent)
                }
            }
            .padding(.vertical, StillTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .stillEntrance()
    }

    private var transitionRitual: some View {
        HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
            Image(systemName: "leaf")
                .foregroundStyle(StillDayPhase.dusk.accent)
                .frame(width: 30, height: 30)
                .background(StillDayPhase.dusk.accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Take a breath before choosing.")
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                Text("You can focus again, take a short break, or be done with Still for now.")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, StillTheme.Spacing.s)
    }

    /// The preference questions deliberately appear only after a person has
    /// experienced one real session. Choosing this never blocks the break or
    /// return actions; Me contains the same editable answers at any time.
    private var firstSessionPreferences: some View {
        Button {
            appState.openPersonalizationAfterFirstSession()
        } label: {
            HStack(spacing: StillTheme.Spacing.s) {
                Image(systemName: "slider.horizontal.3")
                    .font(StillTypography.title3)
                    .foregroundStyle(StillDayPhase.dusk.accent)
                    .frame(width: 38, height: 38)
                    .background(StillDayPhase.dusk.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make Still yours — optional")
                        .font(StillTypography.bodyEmphasis)
                        .foregroundStyle(StillTheme.textPrimary)
                    Text("Choose a focus goal, break preference, or look. You can skip it now and change it in Me later.")
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: StillTheme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .foregroundStyle(StillTheme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(StillTheme.Spacing.m)
            .stillGlass(radius: StillTheme.Radius.medium, phase: .dusk)
        }
        .buttonStyle(StillRowButtonStyle())
        .accessibilityHint("Opens optional preferences in Me. You can also skip them.")
    }

    private func newUnlocks(_ objects: [RoomObject]) -> some View {
        let displayedObjects = Array(objects.prefix(3))
        let primary = objects[0]
        Button {
            appState.router.completion = nil
            appState.router.go(to: .roomCollection)
        } label: {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
                    Image(systemName: "sparkles")
                        .font(StillTypography.title3)
                        .foregroundStyle(StillDayPhase.dusk.accent)
                        .frame(width: 30, height: 30)
                        .background(StillDayPhase.dusk.accent.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(objects.count == 1 ? Copy.Completion.newRoomThing : "New things for your room")
                            .font(StillTypography.caption)
                            .foregroundStyle(StillTheme.textSecondary)
                        Text(objects.count == 1 ? primary.name : "\(objects.count) earned objects")
                            .font(StillTypography.title3)
                            .foregroundStyle(StillTheme.textPrimary)
                        Text(Copy.Completion.placeNewThing)
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textTertiary)
                    }
                    Spacer(minLength: StillTheme.Spacing.xs)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(StillTheme.textSecondary)
                        .accessibilityHidden(true)
                }
                HStack(spacing: StillTheme.Spacing.s) {
                    ForEach(displayedObjects) { object in
                        CompletionUnlockObjectTile(object: object)
                    }
                    if objects.count > displayedObjects.count {
                        Text("+\(objects.count - displayedObjects.count)")
                            .font(StillTypography.caption.weight(.semibold))
                            .foregroundStyle(StillTheme.textSecondary)
                            .frame(width: 52, height: 52)
                            .background(StillTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .accessibilityLabel("\(objects.count - displayedObjects.count) more earned objects")
                    }
                }
            }
            .padding(StillTheme.Spacing.m)
            .stillGlass(radius: StillTheme.Radius.medium, phase: .dusk)
        }
        .buttonStyle(StillRowButtonStyle(feedback: .roomObjectEarned))
        .scaleEffect(unlockIsVisible || reduceMotion ? 1 : 0.01)
        .opacity(unlockIsVisible ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.62), value: unlockIsVisible)
        .onAppear { unlockIsVisible = true }
        .accessibilityLabel("\(objects.count == 1 ? Copy.Completion.newRoomThing : "New room objects"): \(objects.map(\.name).joined(separator: ", ")). \(Copy.Completion.placeNewThing).")
    }

    private func metrics(session: FocusSession?) -> some View {
        let duration = session?.completedFocusDuration ?? 0
        let completedSessions = appState.stats.todayFocus == 0 ? 1 : appState.stats.completedSessions
        let focusDays = max(1, appState.stats.lastSevenDays.filter { $0.focusDuration > 0 }.count)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StillTheme.Spacing.s) {
            CompletionMetric(value: DurationFormatter.short(duration), label: "this session")
            CompletionMetric(value: "\(completedSessions)", label: Copy.Count.sessionLabel(completedSessions))
            CompletionMetric(value: DurationFormatter.short(appState.stats.weekFocus), label: "this week")
            CompletionMetric(value: focusDays == 0 ? "—" : "\(focusDays)", label: Copy.Count.focusDayLabel(focusDays))
        }
        .padding(.vertical, StillTheme.Spacing.s)
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
                    StillInteractionFeedback.fire(.taskMarkedDone, preferences: appState.preferences)
                }
                .buttonStyle(QuietSecondaryButtonStyle())
            }
        }
        .stillInsetRow(verticalPadding: StillTheme.Spacing.s)
    }

    private var usualLine: String {
        guard let usual = appState.stats.usualDailyFocus, usual > 0 else {
            return Copy.Completion.firstUsual
        }
        return Copy.Completion.todayCompared(
            today: DurationFormatter.short(appState.stats.todayFocus),
            usual: DurationFormatter.short(usual)
        )
    }

    private func focusedAmount(_ session: FocusSession?) -> String {
        let seconds = session?.completedFocusDuration ?? 0
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 { return DurationFormatter.short(seconds) }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    /// A small, deterministic discovery rather than an every-session mascot
    /// narration. It is intentionally the only non-settings place a cat name
    /// appears.
    private func catCompletionLine(_ session: FocusSession?) -> String? {
        guard let name = appState.catName, let session else { return nil }
        let checksum = session.id.uuidString.utf8.reduce(0) { $0 + Int($1) }
        guard checksum.isMultiple(of: 5) else { return nil }
        return "\(name) stayed with you the whole time."
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

/// A completion acknowledgement uses the exact original object sprite that
/// will be available in the room collection. It is informative—not a reward
/// chest, inventory currency, or progress meter—and never gates returning to
/// the room or taking a break.
private struct CompletionUnlockObjectTile: View {
    let object: RoomObject

    var body: some View {
        VStack(spacing: 3) {
            Group {
                if let assetName = object.spriteAssetName {
                    Image(assetName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(5)
                } else {
                    Image(systemName: "sparkles")
                        .font(StillTypography.title3)
                        .foregroundStyle(StillDayPhase.dusk.accent)
                }
            }
            .frame(width: 48, height: 38)
            Text(object.name)
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
        }
        .padding(StillTheme.Spacing.xs)
        .frame(width: 92, height: 78)
        .background(StillTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(StillDayPhase.dusk.accent.opacity(0.22), lineWidth: StillTheme.Stroke.hairline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earned object: \(object.name). \(object.summary)")
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
        .stillInsetRow(verticalPadding: StillTheme.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.name), about \(activity.estimatedMinutes) minutes. \(activity.summary)")
    }
}

#Preview("Session complete") {
    let preview = PreviewSupport.completedSession()
    return SessionCompleteView(sessionID: preview.sessionID)
        .environment(preview.state)
}
