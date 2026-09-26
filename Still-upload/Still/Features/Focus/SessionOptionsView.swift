import SwiftUI

/// Edits the selected preset. Controls are grouped by what they change, while
/// the navigation title remains the page's only heading.
struct SessionOptionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: FocusPreset?
    @State private var savedSoundscapeName = ""
    @State private var isNamingSoundscape = false

    var body: some View {
        NavigationStack {
            StillScreen {
                ScrollView {
                    if let preset = draft {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                            presetAndTaskSection(preset)
                            timerSection
                            roomSection(preset)
                            soundSection
                            if appState.container.flags.appBlocking {
                                blockingSection
                            }
                        }
                        .padding(.horizontal, StillTheme.Spacing.screen)
                        .padding(.vertical, StillTheme.Spacing.m)
                    }
                }
                .stillScrollableViewport(reservingFloatingTabBar: false)
            }
            .navigationTitle("Session setup")
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

    private func presetAndTaskSection(_ preset: FocusPreset) -> some View {
        GlassControlGroup {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Preset")
                    Button("Manage") { appState.router.go(to: .presets) }
                        .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
                        .accessibilityHint("Opens presets to add, rename, or delete them.")
                }
                PresetChips(presets: appState.presets, selectedID: preset.id) { id in
                    appState.setDefaultPreset(id)
                    draft = appState.presets.first { $0.id == id }
                }
                InsetRowDivider()
                Button {
                    appState.router.go(to: .tasks)
                } label: {
                    SettingRow(
                        symbol: "checklist",
                        title: appState.selectedTask?.title ?? "No task",
                        value: appState.selectedTask == nil ? "Choose" : "Change"
                    )
                    .stillInsetRow()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Task")
            }
        }
    }

    private var timerSection: some View {
        let mode = binding(\.timer.mode, fallback: .countdown)
        return GlassControlGroup {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                SectionHeader(title: "Timer")
                SelectionPill(options: TimerMode.allCases, selection: mode, title: { $0.displayName })
                InsetRowDivider()
                if mode.wrappedValue != .countUp {
                    minuteStepper(
                        title: mode.wrappedValue == .pomodoro ? "Focus block" : "Focus",
                        value: minutesBinding(\.timer.focusDuration),
                        range: 5...180,
                        step: 5
                    )
                }
                if mode.wrappedValue == .pomodoro {
                    InsetRowDivider()
                    minuteStepper(title: "Break", value: minutesBinding(\.timer.breakDuration), range: 1...60, step: 1)
                    InsetRowDivider()
                    Stepper(value: binding(\.timer.cycleCount, fallback: 4), in: TimerConfiguration.cycleRange) {
                        stepperLabel("Blocks", value: "\(draft?.timer.cycleCount ?? 4)")
                    }
                    .stillInsetRow()
                    InsetRowDivider()
                    Toggle("Start breaks automatically", isOn: binding(\.timer.autoStartBreaks, fallback: true))
                        .font(StillTypography.body)
                        .stillInsetRow()
                    InsetRowDivider()
                    Toggle("Start next focus automatically", isOn: binding(\.timer.autoStartFocus, fallback: false))
                        .font(StillTypography.body)
                        .stillInsetRow()
                }
            }
        }
    }

    private func roomSection(_ preset: FocusPreset) -> some View {
        GlassControlGroup {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                SectionHeader(title: "Room")
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
            }
        }
    }

    private var soundSection: some View {
        GlassControlGroup {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                SectionHeader(title: "Soundscape")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StillTheme.Spacing.xs) {
                        ForEach(SoundscapeCatalog.builtIns) { soundscape in
                            SoundscapeChip(name: soundscape.name) { draft?.ambientMix = soundscape.mix }
                        }
                        ForEach(appState.savedSoundscapes) { soundscape in
                            SoundscapeChip(name: soundscape.name, isCustom: true) { draft?.ambientMix = soundscape.mix }
                        }
                    }
                }
                InsetRowDivider()
                AmbientMixEditor(mix: binding(\.ambientMix, fallback: .silent), status: appState.audioStatus) { source in
                    appState.container.audio.isAssetAvailable(source)
                }
                Button("Save this soundscape") {
                    savedSoundscapeName = ""
                    isNamingSoundscape = true
                }
                .buttonStyle(QuietSecondaryButtonStyle())
            }
        }
        .alert("Save soundscape", isPresented: $isNamingSoundscape) {
            TextField("Name", text: $savedSoundscapeName)
            Button("Save") { appState.saveSoundscape(name: savedSoundscapeName, mix: draft?.ambientMix ?? .silent) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var blockingSection: some View {
        GlassControlGroup {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                SectionHeader(title: "Blocking")
                SelectionPill(options: BlockerIntent.allCases, selection: binding(\.blockerIntent, fallback: .none), title: { $0.displayName })
                InsetRowDivider()
                Button {
                    appState.router.go(to: .blockingSetup)
                } label: {
                    SettingRow(symbol: "shield", title: "Choose apps", value: nil)
                        .stillInsetRow()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func minuteStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            stepperLabel(title, value: "\(value.wrappedValue) min")
        }
        .stillInsetRow()
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
                RoomHeroView(sceneName: scene.name, sceneID: scene.id, plantStage: .full)
                    .frame(width: 112, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                            .strokeBorder(isSelected ? StillTheme.accent : StillTheme.border,
                                          lineWidth: isSelected ? 2 : StillTheme.Stroke.hairline)
                    )
                HStack(spacing: 4) {
                    Text(scene.name)
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textPrimary)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(StillTypography.caption.weight(.semibold))
                            .foregroundStyle(StillTheme.accent)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scene.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Restrained local sound controls. Their parent supplies the one surrounding
/// glass control group; this editor does not manufacture a nested card.
struct AmbientMixEditor: View {
    @Binding var mix: AmbientMix
    let status: AmbientAudioStatus
    let isAvailable: (AmbientSourceID) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            if status == .assetsMissing {
                QuietNote(text: AmbientAudioCopy.assetsMissing)
            } else if status == .unavailable {
                QuietNote(text: AmbientAudioCopy.unavailable)
            }
            Toggle("Ambient sound", isOn: $mix.isEnabled)
                .font(StillTypography.body)
                .stillInsetRow()
            if mix.isEnabled {
                InsetRowDivider()
                levelRow(title: "Volume", value: Binding(get: { mix.masterVolume }, set: { mix.setMasterVolume($0) }), note: nil)
                ForEach(AmbientSource.all) { source in
                    InsetRowDivider()
                    levelRow(
                        title: source.displayName,
                        value: Binding(get: { mix.level(for: source.id) }, set: { mix.setLevel($0, for: source.id) }),
                        note: (status == .ready && !isAvailable(source.id)) ? AmbientAudioCopy.sourceMissing : nil
                    )
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
        .stillInsetRow()
    }
}

private struct SoundscapeChip: View {
    let name: String
    var isCustom = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isCustom ? "person.crop.circle" : "cloud")
                Text(name)
            }
            .font(StillTypography.caption)
            .foregroundStyle(StillTheme.textPrimary)
            .padding(.horizontal, StillTheme.Spacing.s)
            .frame(minHeight: StillTheme.minimumTapSize)
            .background(StillTheme.accentSoft.opacity(0.32), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCustom ? "Custom soundscape: \(name)" : "Soundscape: \(name)")
    }
}
