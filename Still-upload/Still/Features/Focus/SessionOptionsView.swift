import SwiftUI

/// Everything that would crowd the Focus screen: preset, task, timer,
/// environment, and sound. Edits save to the selected preset immediately.
struct SessionOptionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: FocusPreset?

    var body: some View {
        NavigationStack {
            StillScreen {
                ScrollView {
                    if let preset = draft {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                            presetSection(preset)
                            taskSection
                            timerSection
                            environmentSection(preset)
                            soundSection
                            if appState.container.flags.appBlocking {
                                blockingSection
                            }
                        }
                        .padding(.horizontal, StillTheme.Spacing.screen)
                        .padding(.vertical, StillTheme.Spacing.m)
                    }
                }
            }
            .navigationTitle("Session options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if draft == nil { draft = appState.currentPreset }
        }
        .onChange(of: draft) { _, newValue in
            if let newValue, newValue != appState.presets.first(where: { $0.id == newValue.id }) {
                appState.savePreset(newValue)
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Bindings into the draft

    private func binding<Value>(_ keyPath: WritableKeyPath<FocusPreset, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { draft?[keyPath: keyPath] ?? fallback },
            set: { newValue in draft?[keyPath: keyPath] = newValue }
        )
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<FocusPreset, TimeInterval>) -> Binding<Int> {
        Binding(
            get: { Int(((draft?[keyPath: keyPath] ?? 0) / 60).rounded()) },
            set: { newValue in draft?[keyPath: keyPath] = TimeInterval(newValue * 60) }
        )
    }

    // MARK: Sections

    private func presetSection(_ preset: FocusPreset) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Preset", detail: "Focus starts with this preset. Changes below apply to it.")
                Button("Manage") {
                    appState.router.go(to: .presets)
                }
                .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
                .accessibilityHint("Opens your presets to add, rename, or delete them.")
            }
            PresetChips(presets: appState.presets, selectedID: preset.id) { id in
                appState.setDefaultPreset(id)
                draft = appState.presets.first { $0.id == id }
            }
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Task")
            Button {
                appState.router.go(to: .tasks)
            } label: {
                SettingRow(symbol: "checklist", title: appState.selectedTask?.title ?? "No task", value: appState.selectedTask == nil ? "Choose" : "Change")
            }
            .buttonStyle(.plain)
        }
    }

    private var timerSection: some View {
        let mode = binding(\.timer.mode, fallback: .countdown)
        return VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Timer")
            SelectionPill(options: TimerMode.allCases, selection: mode, title: { $0.displayName })

            StillCard {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                    if mode.wrappedValue == .countUp {
                        Text("Count up runs until you finish. Sessions under 5 minutes aren't counted.")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        minuteStepper(title: mode.wrappedValue == .pomodoro ? "Focus block" : "Focus",
                                      value: minutesBinding(\.timer.focusDuration), range: 5...180, step: 5)
                    }
                    if mode.wrappedValue == .pomodoro {
                        Divider()
                        minuteStepper(title: "Break", value: minutesBinding(\.timer.breakDuration), range: 1...60, step: 1)
                        Divider()
                        Stepper(value: binding(\.timer.cycleCount, fallback: 4), in: TimerConfiguration.cycleRange) {
                            stepperLabel("Blocks", value: "\(draft?.timer.cycleCount ?? 4)")
                        }
                        Divider()
                        Toggle("Start breaks automatically", isOn: binding(\.timer.autoStartBreaks, fallback: true))
                            .font(StillTypography.body)
                        Toggle("Start next focus automatically", isOn: binding(\.timer.autoStartFocus, fallback: false))
                            .font(StillTypography.body)
                    }
                }
            }
        }
    }

    private func environmentSection(_ preset: FocusPreset) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Environment", detail: "Calm keeps a still plant and puts the timer first.")
            SelectionPill(options: RenderMode.allCases, selection: binding(\.renderMode, fallback: .scene), title: { $0.displayName })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StillTheme.Spacing.s) {
                    ForEach(SceneCatalog.all.filter { appState.isUnlocked($0) }) { scene in
                        SceneChoice(scene: scene, isSelected: scene.id == preset.sceneID) {
                            draft?.sceneID = scene.id
                            draft?.renderMode = .scene
                        }
                    }
                }
            }
            if let next = appState.nextLockedScene {
                Text("\(next.scene.name) opens after \(next.remaining) more \(next.remaining == 1 ? "session" : "sessions").")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textTertiary)
            }
        }
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Sound")
            AmbientMixEditor(mix: binding(\.ambientMix, fallback: .silent), status: appState.audioStatus) { source in
                appState.container.audio.isAssetAvailable(source)
            }
        }
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Blocking", detail: "What this preset shields while a session runs. You can end blocking early at any time.")
            SelectionPill(options: BlockerIntent.allCases, selection: binding(\.blockerIntent, fallback: .none), title: { $0.displayName })
            Button {
                appState.router.go(to: .blockingSetup)
            } label: {
                SettingRow(symbol: "shield", title: "Choose apps", value: nil)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Small pieces

    private func minuteStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            stepperLabel(title, value: "\(value.wrappedValue) min")
        }
        .accessibilityValue("\(value.wrappedValue) minutes")
    }

    private func stepperLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(StillTypography.body)
                .foregroundStyle(StillTheme.textPrimary)
            Spacer()
            Text(value)
                .font(StillTypography.body.monospacedDigit())
                .foregroundStyle(StillTheme.textSecondary)
        }
    }
}

private struct SceneChoice: View {
    let scene: SceneDefinition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                PixelSceneView(scene: scene, mode: .scene, intensity: .still)
                    .frame(width: 112, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                            .strokeBorder(isSelected ? StillTheme.accent : StillTheme.border,
                                          lineWidth: isSelected ? 2 : StillTheme.Stroke.hairline)
                    )
                Text(scene.name)
                    .font(StillTypography.caption)
                    .foregroundStyle(StillTheme.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scene.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Restrained sound controls: an on/off switch, a master level, and one
/// level per source. No meters or visualizers.
struct AmbientMixEditor: View {
    @Binding var mix: AmbientMix
    let status: AmbientAudioStatus
    let isAvailable: (AmbientSourceID) -> Bool

    var body: some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                if status == .assetsMissing {
                    QuietNote(text: AmbientAudioCopy.assetsMissing)
                } else if status == .unavailable {
                    QuietNote(text: AmbientAudioCopy.unavailable)
                }
                Toggle("Ambient sound", isOn: $mix.isEnabled)
                    .font(StillTypography.body)
                if mix.isEnabled {
                    levelRow(title: "Volume", value: Binding(get: { mix.masterVolume }, set: { mix.setMasterVolume($0) }), note: nil)
                    Divider()
                    ForEach(AmbientSource.all) { source in
                        levelRow(
                            title: source.displayName,
                            value: Binding(get: { mix.level(for: source.id) }, set: { mix.setLevel($0, for: source.id) }),
                            note: (status == .ready && !isAvailable(source.id)) ? AmbientAudioCopy.sourceMissing : nil
                        )
                    }
                }
            }
        }
    }

    private func levelRow(title: String, value: Binding<Double>, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textPrimary)
                Spacer()
                Text(value.wrappedValue < 0.01 ? "Off" : "\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(StillTypography.footnote.monospacedDigit())
                    .foregroundStyle(StillTheme.textSecondary)
            }
            Slider(value: value, in: 0...1)
                .accessibilityLabel(title)
                .accessibilityValue(value.wrappedValue < 0.01 ? "Off" : "\(Int((value.wrappedValue * 100).rounded())) percent")
            if let note {
                Text(note)
                    .font(StillTypography.caption)
                    .foregroundStyle(StillTheme.textTertiary)
            }
        }
    }
}

#Preview("Session options") {
    SessionOptionsView()
        .environment(PreviewSupport.appState(populated: true))
}
