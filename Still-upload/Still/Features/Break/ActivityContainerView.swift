import SwiftUI

/// Hosts every activity with the same header (Back to Break, name, remaining
/// time, Done), usage tracking, and a finished state that returns to Break or
/// Focus. Text and puzzle progress autosave, so leaving never loses work.
struct ActivityContainerView: View {
    let activityID: BreakActivityID
    let context: ActivityContext

    @Environment(AppState.self) private var appState
    @State private var usage: ActivityUsage?
    @State private var outcome: ActivityOutcome?

    private var activity: BreakActivity? { ActivityCatalog.activity(activityID) }

    /// Puzzles only count as completed when solved; Done on an unsolved puzzle
    /// keeps its progress and records the visit as unfinished.
    private var completesOnDone: Bool {
        activity?.category != .puzzle
    }

    var body: some View {
        let startedAt = usage?.startedAt ?? Date()
        StillScreen {
            VStack(spacing: 0) {
                ActivityHeader(
                    title: activity?.name ?? "Activity",
                    startedAt: startedAt,
                    duration: activity?.estimatedDuration ?? 60,
                    showsRemainingTime: activity?.category != .puzzle && activityID != .boxBreathing,
                    isFinished: outcome != nil,
                    onBack: backToBreak,
                    onDone: done
                )
                ScrollViewReader { proxy in
                    GeometryReader { viewport in
                        ScrollView {
                            VStack(spacing: 0) {
                                activityBody(startedAt: startedAt, availableSize: viewport.size)
                                Color.clear.frame(height: 1).id("activity-bottom")
                            }
                            .padding(.horizontal, StillTheme.Spacing.screen)
                            .padding(.vertical, StillTheme.Spacing.m)
                        }
                        .stillScrollableViewport()
                        .onAppear {
                            #if DEBUG
                            let shouldScroll = (activityID == .shortRead && DemoLaunch.shouldScrollToBottom("read"))
                                || (activityID == .sudoku && DemoLaunch.shouldScrollToBottom("sudoku"))
                            guard shouldScroll else { return }
                            DispatchQueue.main.async { proxy.scrollTo("activity-bottom", anchor: .bottom) }
                            #endif
                        }
                    }
                }
                if let outcome {
                    ActivityFinishedPanel(
                        title: finishedTitle(outcome),
                        message: finishedMessage(outcome),
                        onFocus: { appState.returnToFocusFromActivity() },
                        onShelf: { appState.returnToShelf() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if usage == nil {
                usage = appState.beginActivity(activityID, context: context)
            }
        }
    }

    @ViewBuilder
    private func activityBody(startedAt: Date, availableSize: CGSize) -> some View {
        switch activityID {
        case .sudoku:
            SudokuActivityView(onSolved: { finish(.completed) })
        case .picross:
            PicrossActivityView(onSolved: { finish(.completed) }, availableSize: availableSize)
        case .wordSearch:
            WordSearchActivityView(onSolved: { finish(.completed) })
        case .shortRead:
            ShortReadActivityView(onFinished: { finish(.completed) })
        case .creativePrompt:
            CreativePromptActivityView()
        case .pixelDoodle:
            PixelDoodleActivityView()
        case .brainDump:
            BrainDumpActivityView()
        case .guidedStretch:
            GuidedStretchActivityView(onFinished: { finish(.completed) })
        case .boxBreathing:
            BoxBreathingActivityView(startedAt: startedAt, isFinished: outcome != nil, onFinished: { finish(.completed) })
        case .doNothing:
            DoNothingActivityView(startedAt: startedAt, duration: activity?.estimatedDuration ?? 60,
                                  isFinished: outcome != nil, onFinished: { finish(.completed) })
        default:
            EmptyState(symbol: "questionmark.circle", title: "Not available", message: "This activity isn't part of this version.")
        }
    }

    // MARK: Actions

    private func finish(_ result: ActivityOutcome) {
        guard outcome == nil else { return }
        withAnimation(.easeOut(duration: StillMotion.standard)) {
            outcome = result
        }
        if let usage {
            appState.finishActivity(usage.id, outcome: result)
        }
    }

    private func done() {
        if outcome == nil {
            finish(completesOnDone ? .completed : .abandoned)
        }
    }

    private func backToBreak() {
        if outcome == nil, let usage {
            appState.finishActivity(usage.id, outcome: .abandoned)
        }
        appState.returnToShelf()
    }

    private func finishedTitle(_ result: ActivityOutcome) -> String {
        if result == .abandoned { return "Saved for later." }
        return activity?.category == .puzzle ? "Solved." : "That's it."
    }

    private func finishedMessage(_ result: ActivityOutcome) -> String {
        if result == .abandoned { return "Your progress is kept on this device." }
        return "Ready to focus again, or take a little longer?"
    }
}

/// Back to Break · name · remaining time · Done.
struct ActivityHeader: View {
    let title: String
    let startedAt: Date
    let duration: TimeInterval
    var showsRemainingTime: Bool = true
    let isFinished: Bool
    let onBack: () -> Void
    let onDone: () -> Void
    @Environment(\.stillDayPhase) private var phase
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let resolved = phase ?? StillDayPhase.automatic(colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            HStack {
                Button(action: onBack) {
                    Label("Back to Break", systemImage: "chevron.left")
                        .font(StillTypography.callout.weight(.medium))
                }
                .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.textPrimary))
                Spacer()
                if !isFinished {
                    Button("Done", action: onDone)
                        .buttonStyle(QuietSecondaryButtonStyle())
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(StillTypography.title)
                    .foregroundStyle(StillTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !isFinished && showsRemainingTime {
                    TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
                        let remaining = max(0, duration - timeline.date.timeIntervalSince(startedAt))
                        Text(remaining > 0 ? "\(DurationFormatter.clock(remaining)) left" : "Take your time")
                            .font(StillTypography.footnote.monospacedDigit())
                            .foregroundStyle(StillTheme.textSecondary)
                            .accessibilityLabel(remaining > 0 ? "About \(DurationFormatter.spoken(remaining)) left" : "Take your time")
                    }
                }
            }
        }
        .padding(.horizontal, StillTheme.Spacing.screen)
        .padding(.top, StillTheme.Spacing.xs)
        .padding(.bottom, StillTheme.Spacing.s)
        .background(.ultraThinMaterial)
        .background(resolved.glassFill)
        .overlay(alignment: .bottom) {
            Rectangle().fill(resolved.glassBorder).frame(height: StillTheme.Stroke.hairline)
        }
    }
}

/// The explicit endpoint every activity reaches.
struct ActivityFinishedPanel: View {
    let title: String
    let message: String
    let onFocus: () -> Void
    let onShelf: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            Text(title)
                .font(StillTypography.title3)
                .foregroundStyle(StillTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Return to Focus", action: onFocus)
                .buttonStyle(QuietPrimaryButtonStyle())
            Button("Back to Break", action: onShelf)
                .buttonStyle(QuietSecondaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(StillTheme.Spacing.l)
        .background(.ultraThinMaterial)
        .stillGlass(radius: StillTheme.Radius.large)
        .ignoresSafeArea(edges: .bottom)
    }
}
