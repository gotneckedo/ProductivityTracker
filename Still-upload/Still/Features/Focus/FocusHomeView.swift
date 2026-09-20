import SwiftUI

/// Tap → Start. The environment, the task, the duration, one Start control,
/// an understated sound line, and a compact "Session options" entry.
struct FocusHomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let preset = appState.currentPreset
        let scene = displayScene(for: preset)
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    header(preset: preset)

                    PixelSceneView(scene: scene, mode: preset.renderMode, intensity: appState.animationIntensity)
                        .aspectRatio(PixelSceneView.preferredAspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.scene, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: StillTheme.Radius.scene, style: .continuous)
                                .strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline)
                        )
                        .stillEntrance()

                    if let unlocked = appState.newlyUnlockedScenes.first {
                        QuietNote(text: "\(unlocked.name) is open now. You'll find it in Me.", symbol: "leaf")
                    }

                    TaskRow(task: appState.selectedTask, emphasized: appState.personalization.emphasizesTasks) {
                        appState.router.go(to: .tasks)
                    }

                    DurationSummary(timer: preset.timer)

                    Button {
                        appState.startFocus()
                    } label: {
                        Label("Start Focus", systemImage: "play.fill")
                            .labelStyle(.titleOnly)
                    }
                    .buttonStyle(QuietPrimaryButtonStyle())
                    .accessibilityHint("Starts \(DurationFormatter.short(preset.timer.focusDuration)) of focus.")

                    HStack(alignment: .center, spacing: StillTheme.Spacing.s) {
                        Label(preset.ambientMix.summaryLine, systemImage: preset.ambientMix.isSilent ? "speaker.slash" : "speaker.wave.1")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                            .lineLimit(1)
                            .accessibilityLabel("Sound: \(preset.ambientMix.summaryLine)")
                        Spacer(minLength: StillTheme.Spacing.xs)
                        Button("Session options") {
                            appState.router.go(to: .focusConfiguration)
                        }
                        .buttonStyle(QuietSecondaryButtonStyle())
                    }
                    if appState.audioStatus == .assetsMissing && !preset.ambientMix.isSilent {
                        QuietNote(text: AmbientAudioCopy.assetsMissing)
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.top, StillTheme.Spacing.m)
                .padding(.bottom, StillTheme.Spacing.xl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func header(preset: FocusPreset) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
            Text(appState.personalization.homeGreeting)
                .font(StillTypography.title)
                .foregroundStyle(StillTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("\(preset.name) · \(preset.renderMode.displayName) mode")
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textSecondary)
        }
    }

    /// Shows the preset's scene, or the first scene if it's still locked.
    private func displayScene(for preset: FocusPreset) -> SceneDefinition {
        let scene = appState.scene(preset.sceneID)
        return appState.isUnlocked(scene) ? scene : SceneCatalog.rainyBedroom
    }
}

private struct TaskRow: View {
    let task: TaskItem?
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: StillTheme.Spacing.s) {
                Image(systemName: task == nil ? "plus.circle" : "circle")
                    .foregroundStyle(task == nil ? StillTheme.textTertiary : StillTheme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task == nil ? "Task" : "Focusing on")
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textTertiary)
                    Text(task?.title ?? (emphasized ? "Add one thing to work on" : "Optional"))
                        .font(StillTypography.body)
                        .foregroundStyle(task == nil ? StillTheme.textSecondary : StillTheme.textPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: StillTheme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(StillTypography.footnote.weight(.semibold))
                    .foregroundStyle(StillTheme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(StillTheme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                    .fill(StillTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                    .strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens today's tasks.")
    }
}

/// "25 min" with a plain description of the timer underneath.
struct DurationSummary: View {
    let timer: TimerConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
            Text(headline)
                .font(StillTypography.display.monospacedDigit())
                .foregroundStyle(StillTheme.textPrimary)
            Text(detail)
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        timer.mode == .countUp ? "Open-ended" : DurationFormatter.short(timer.focusDuration)
    }

    private var detail: String {
        switch timer.mode {
        case .countdown:
            return "Countdown"
        case .countUp:
            return "Count up. Finish whenever you're ready."
        case .pomodoro:
            let blocks = timer.focusBlockCount
            return "Pomodoro · \(blocks) \(blocks == 1 ? "block" : "blocks"), \(DurationFormatter.short(timer.breakDuration)) breaks"
        }
    }
}

#Preview("Focus home · Scene") {
    FocusHomeView()
        .environment(PreviewSupport.appState(renderMode: .scene))
}

#Preview("Focus home · Calm") {
    FocusHomeView()
        .environment(PreviewSupport.appState(goal: .calmerPhone, renderMode: .calm))
}

#Preview("Focus home · Large text") {
    FocusHomeView()
        .environment(PreviewSupport.appState(populated: true))
        .dynamicTypeSize(.accessibility2)
}
