import SwiftUI

/// All presets: choose the default, make a new one from any preset, rename,
/// or delete the ones you made. Timer, scene, and sound are edited in
/// Session options, which always edits the default preset.
struct PresetsView: View {
    @Environment(AppState.self) private var appState
    @State private var naming: NamingRequest?
    @State private var nameText = ""
    @State private var deleting: FocusPreset?

    private struct NamingRequest: Identifiable {
        enum Kind { case create(basedOn: FocusPreset), rename(FocusPreset) }
        let id = UUID()
        let kind: Kind
    }

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Presets")
                            .font(StillTypography.display)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("A preset is a timer, a scene, and a sound. Tap one to make it your default. Each one has its own Focus Card link.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: StillTheme.Spacing.s) {
                        ForEach(appState.presets) { preset in
                            PresetRow(
                                preset: preset,
                                isDefault: preset.id == appState.currentPreset.id,
                                onSelect: { appState.setDefaultPreset(preset.id) },
                                onDuplicate: { beginNaming(.create(basedOn: preset)) },
                                onRename: { beginNaming(.rename(preset)) },
                                onDelete: { deleting = preset }
                            )
                        }
                    }

                    if appState.canCreatePreset {
                        Button {
                            beginNaming(.create(basedOn: appState.currentPreset))
                        } label: {
                            Label("New preset", systemImage: "plus")
                        }
                        .buttonStyle(QuietSecondaryButtonStyle())
                    } else {
                        QuietNote(text: "Ten presets is the limit. Delete one to make room.")
                    }

                    Button {
                        appState.router.go(to: .focusConfiguration)
                    } label: {
                        SettingRow(symbol: "slider.horizontal.3", title: "Edit \(appState.currentPreset.name)", value: "Session options")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert(namingTitle, isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField("Name", text: $nameText)
            Button("Save", action: commitName)
            Button("Cancel", role: .cancel) { naming = nil }
        } message: {
            Text(namingMessage)
        }
        .confirmationDialog("Delete this preset?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete \(deleting?.name ?? "preset")", role: .destructive) {
                if let preset = deleting { appState.deletePreset(preset.id) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Focus Cards written with its link will start Default instead.")
        }
    }

    private var namingTitle: String {
        guard let naming else { return "" }
        switch naming.kind {
        case .create: return "New preset"
        case .rename: return "Rename preset"
        }
    }

    private var namingMessage: String {
        guard let naming else { return "" }
        switch naming.kind {
        case .create(let base): return "Starts as a copy of \(base.name). You can change the timer, scene, and sound after."
        case .rename: return "Links on your Focus Cards keep working."
        }
    }

    private func beginNaming(_ kind: NamingRequest.Kind) {
        switch kind {
        case .create(let base): nameText = base.isBuiltIn ? "" : "\(base.name) copy"
        case .rename(let preset): nameText = preset.name
        }
        naming = NamingRequest(kind: kind)
    }

    private func commitName() {
        guard let naming else { return }
        switch naming.kind {
        case .create(let base):
            if let created = appState.createPreset(named: nameText, basedOn: base) {
                appState.setDefaultPreset(created.id)
            }
        case .rename(let preset):
            appState.renamePreset(preset.id, to: nameText)
        }
        self.naming = nil
    }
}

private struct PresetRow: View {
    let preset: FocusPreset
    let isDefault: Bool
    let onSelect: () -> Void
    let onDuplicate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Button(action: onSelect) {
                HStack(spacing: StillTheme.Spacing.s) {
                    Image(systemName: isDefault ? "largecircle.fill.circle" : "circle")
                        .font(StillTypography.title3)
                        .foregroundStyle(isDefault ? StillTheme.accent : StillTheme.textTertiary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name)
                            .font(StillTypography.bodyEmphasis)
                            .foregroundStyle(StillTheme.textPrimary)
                        Text(detail)
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(preset.name)
            .accessibilityValue(isDefault ? "Default. \(detail)" : detail)
            .accessibilityHint(isDefault ? "" : "Makes this the default preset.")

            Menu {
                Button(action: onDuplicate) { Label("New preset from this", systemImage: "plus.square.on.square") }
                if !preset.isBuiltIn {
                    Button(action: onRename) { Label("Rename", systemImage: "pencil") }
                    Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(StillTypography.body)
                    .foregroundStyle(StillTheme.textSecondary)
                    .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More for \(preset.name)")
        }
        .padding(.horizontal, StillTheme.Spacing.s)
        .padding(.vertical, StillTheme.Spacing.s)
        .stillGlass(radius: StillTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                .strokeBorder(isDefault ? StillTheme.accent : Color.clear, lineWidth: isDefault ? 2 : 0)
        )
    }

    private var detail: String {
        var parts = [DurationSummaryText.short(preset.timer), preset.renderMode.displayName]
        if !preset.ambientMix.isSilent { parts.append(preset.ambientMix.summaryLine) }
        return parts.joined(separator: " · ")
    }
}

/// Horizontally scrolling preset chips, used in Session options.
struct PresetChips: View {
    let presets: [FocusPreset]
    let selectedID: FocusPresetID
    let onSelect: (FocusPresetID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StillTheme.Spacing.xs) {
                ForEach(presets) { preset in
                    let isSelected = preset.id == selectedID
                    Button {
                        onSelect(preset.id)
                    } label: {
                        Text(preset.name)
                            .font(StillTypography.callout.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? StillTheme.textPrimary : StillTheme.textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, StillTheme.Spacing.m)
                            .frame(minHeight: 38)
                            .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                            .overlay(Capsule(style: .continuous).fill(isSelected ? Color.white.opacity(0.30) : Color.white.opacity(0.08)))
                            .overlay(Capsule(style: .continuous).strokeBorder(isSelected ? StillTheme.accent : StillTheme.border, lineWidth: StillTheme.Stroke.hairline))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview("Presets") {
    NavigationStack {
        PresetsView()
    }
    .environment(PreviewSupport.appState(populated: true))
}
