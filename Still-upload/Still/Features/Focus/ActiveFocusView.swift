import SwiftUI

/// The quiet running screen: environment, time, task, sound, pause, end.
struct ActiveFocusView: View {
    @Environment(AppState.self) private var appState
    @State private var isConfirmingEnd = false

    var body: some View {
        Group {
            if let session = appState.activeSession, let snapshot = appState.snapshot {
                content(session: session, snapshot: snapshot)
            } else {
                StillTheme.background.ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            // Time is derived from stored dates; this loop only refreshes the display
            // and lets the controller notice phase ends while the screen is open.
            while !Task.isCancelled {
                await MainActor.run { appState.tick() }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .confirmationDialog("End this session early?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button("End session", role: .destructive) {
                appState.endSessionEarly()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("It won't count toward your stats or scenes.")
        }
    }

    @ViewBuilder
    private func content(session: FocusSession, snapshot: TimerSnapshot) -> some View {
        let scene = appState.scene(session.sceneID)
        let onScene = session.renderMode == .scene
        let background = onScene ? scene.surroundColor : StillTheme.background

        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: StillTheme.Spacing.l) {
                    PixelSceneView(scene: scene, mode: session.renderMode, intensity: appState.animationIntensity)
                        .aspectRatio(PixelSceneView.preferredAspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.scene, style: .continuous))
                        .frame(maxWidth: onScene ? .infinity : 240)
                        .padding(.top, StillTheme.Spacing.s)

                    SessionTimerFace(
                        time: timeText(snapshot),
                        caption: caption(snapshot),
                        progress: snapshot.phaseProgress,
                        isPaused: snapshot.isPaused,
                        accessibilityText: spokenState(snapshot),
                        surface: onScene ? .scene : .paper
                    )

                    if let task = appState.task(session.taskID) {
                        Text(task.title)
                            .font(StillTypography.callout)
                            .foregroundStyle(onScene ? StillTheme.Palette.sceneTextSecondary : StillTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .accessibilityLabel("Task: \(task.title)")
                    }

                    controls(snapshot: snapshot, onScene: onScene)

                    soundLine(session: session, onScene: onScene)
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.bottom, StillTheme.Spacing.xl)
            }
        }
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(snapshot: TimerSnapshot, onScene: Bool) -> some View {
        let primaryFill = onScene ? StillTheme.Palette.sceneText : StillTheme.accent
        let primaryText = onScene ? StillTheme.Palette.navyShadow : StillTheme.onAccent
        let secondaryText = onScene ? StillTheme.Palette.sceneText : StillTheme.textPrimary
        let secondaryBorder = onScene ? StillTheme.Palette.sceneText.opacity(0.35) : StillTheme.border
        let tertiaryText = onScene ? StillTheme.Palette.sceneTextSecondary : StillTheme.textSecondary

        VStack(spacing: StillTheme.Spacing.s) {
            if snapshot.isAwaitingNextPhase {
                Button(snapshot.nextPhaseKind == .focus ? "Start next focus" : "Start break") {
                    appState.startNextPhase()
                }
                .buttonStyle(QuietPrimaryButtonStyle(fill: primaryFill, foreground: primaryText))
                if snapshot.nextPhaseKind?.isBreak == true {
                    Button("Skip break") { appState.skipBreak() }
                        .buttonStyle(QuietSecondaryButtonStyle(foreground: secondaryText, border: secondaryBorder))
                }
            } else if snapshot.mode == .countUp {
                Button("Finish") { appState.finishCountUp() }
                    .buttonStyle(QuietPrimaryButtonStyle(fill: primaryFill, foreground: primaryText))
                    .accessibilityHint("Ends the session and records the time you focused.")
                pauseResumeButton(snapshot: snapshot, foreground: secondaryText, border: secondaryBorder)
            } else if snapshot.phaseKind.isBreak {
                Button("Skip break") { appState.skipBreak() }
                    .buttonStyle(QuietPrimaryButtonStyle(fill: primaryFill, foreground: primaryText))
                pauseResumeButton(snapshot: snapshot, foreground: secondaryText, border: secondaryBorder)
            } else {
                pauseResumeButton(snapshot: snapshot, foreground: secondaryText, border: secondaryBorder, prominent: true,
                                  fill: primaryFill, prominentText: primaryText)
            }

            Button("End session") { isConfirmingEnd = true }
                .buttonStyle(QuietTextButtonStyle(foreground: tertiaryText))
                .accessibilityHint("Asks before ending. Ended sessions don't count toward stats.")
        }
    }

    @ViewBuilder
    private func pauseResumeButton(snapshot: TimerSnapshot, foreground: Color, border: Color, prominent: Bool = false,
                                   fill: Color = StillTheme.accent, prominentText: Color = StillTheme.onAccent) -> some View {
        let title = snapshot.isPaused ? "Resume" : "Pause"
        if prominent {
            Button(title) { snapshot.isPaused ? appState.resume() : appState.pause() }
                .buttonStyle(QuietPrimaryButtonStyle(fill: fill, foreground: prominentText))
                .accessibilityValue(snapshot.isPaused ? "Paused" : "Running")
        } else {
            Button(title) { snapshot.isPaused ? appState.resume() : appState.pause() }
                .buttonStyle(QuietSecondaryButtonStyle(foreground: foreground, border: border))
                .accessibilityValue(snapshot.isPaused ? "Paused" : "Running")
        }
    }

    @ViewBuilder
    private func soundLine(session: FocusSession, onScene: Bool) -> some View {
        let mix = appState.presets.first { $0.id == session.presetID }?.ambientMix ?? .silent
        let color = onScene ? StillTheme.Palette.sceneTextSecondary : StillTheme.textSecondary
        if appState.audioStatus != .ready && !mix.isSilent {
            Text(appState.audioStatus == .assetsMissing ? AmbientAudioCopy.assetsMissing : AmbientAudioCopy.unavailable)
                .font(StillTypography.footnote)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
        } else if mix.isSilent {
            Label("Sound off", systemImage: "speaker.slash")
                .font(StillTypography.footnote)
                .foregroundStyle(color)
        } else {
            Button {
                appState.toggleMute()
            } label: {
                Label(appState.isAudioMuted ? "Sound muted" : mix.summaryLine,
                      systemImage: appState.isAudioMuted ? "speaker.slash" : "speaker.wave.1")
                    .font(StillTypography.footnote)
                    .foregroundStyle(color)
            }
            .buttonStyle(QuietTextButtonStyle(foreground: color))
            .accessibilityLabel(appState.isAudioMuted ? "Sound muted" : "Sound: \(mix.summaryLine)")
            .accessibilityHint(appState.isAudioMuted ? "Turns sound back on." : "Mutes sound for this session.")
        }
    }

    // MARK: Text

    private func timeText(_ snapshot: TimerSnapshot) -> String {
        snapshot.remainingInPhase == nil
            ? DurationFormatter.elapsedClock(snapshot.elapsedInPhase)
            : DurationFormatter.clock(snapshot.displayedSeconds)
    }

    private func caption(_ snapshot: TimerSnapshot) -> String {
        if snapshot.isAwaitingNextPhase {
            return snapshot.nextPhaseKind == .focus ? "Ready for the next block" : "Break is ready"
        }
        if snapshot.isPaused { return "Paused" }
        switch snapshot.mode {
        case .countUp:
            return "Focused"
        case .countdown:
            return "Focus"
        case .pomodoro:
            return snapshot.phaseKind.isBreak
                ? snapshot.phaseKind.displayName
                : "Focus · \(snapshot.focusBlockNumber) of \(snapshot.focusBlockCount)"
        }
    }

    private func spokenState(_ snapshot: TimerSnapshot) -> String {
        let amount = DurationFormatter.spoken(snapshot.displayedSeconds)
        let base = snapshot.remainingInPhase == nil ? "\(amount) elapsed" : "\(amount) remaining"
        if snapshot.isAwaitingNextPhase { return "Waiting to start the next block" }
        return snapshot.isPaused ? "Paused. \(base)" : base
    }
}

#Preview("Active focus · Scene") {
    FocusTab()
        .environment(PreviewSupport.appState(renderMode: .scene, activeSession: true))
}

#Preview("Active focus · Calm") {
    FocusTab()
        .environment(PreviewSupport.appState(goal: .calmerPhone, renderMode: .calm, activeSession: true))
}
