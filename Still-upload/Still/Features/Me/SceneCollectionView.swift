import SwiftUI

/// Scenes and how they open. Unlock conditions are stated quietly; there is
/// no reward burst, nothing to buy, and nothing to lose.
struct SceneCollectionView: View {
    @Environment(AppState.self) private var appState

    private let columns = [GridItem(.flexible(), spacing: StillTheme.Spacing.m), GridItem(.flexible(), spacing: StillTheme.Spacing.m)]

    var body: some View {
        let preset = appState.currentPreset
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Scenes")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("New scenes open as you complete sessions. Choose one for \(preset.name).")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LazyVGrid(columns: columns, alignment: .leading, spacing: StillTheme.Spacing.l) {
                        ForEach(SceneCatalog.all) { scene in
                            SceneCard(
                                scene: scene,
                                isUnlocked: appState.isUnlocked(scene),
                                isSelected: preset.sceneID == scene.id && preset.renderMode == .scene,
                                remaining: max(0, scene.unlockRule.requiredSessions - appState.completedSessionCount)
                            ) {
                                var edited = preset
                                edited.sceneID = scene.id
                                edited.renderMode = .scene
                                appState.savePreset(edited)
                            }
                        }
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { appState.acknowledgeUnlockedScenes() }
    }
}

private struct SceneCard: View {
    let scene: SceneDefinition
    let isUnlocked: Bool
    let isSelected: Bool
    let remaining: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                ZStack {
                    PixelSceneView(scene: scene, mode: .scene, intensity: .still)
                        .saturation(isUnlocked ? 1 : 0.2)
                        .opacity(isUnlocked ? 1 : 0.55)
                    if !isUnlocked {
                        Image(systemName: "lock")
                            .font(StillTypography.title3)
                            .foregroundStyle(StillTheme.Palette.sceneText)
                            .padding(StillTheme.Spacing.s)
                            .background(Circle().fill(StillTheme.Palette.navyShadow.opacity(0.6)))
                    }
                }
                .aspectRatio(PixelSceneView.preferredAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                        .strokeBorder(isSelected ? StillTheme.accent : StillTheme.border, lineWidth: isSelected ? 2 : StillTheme.Stroke.hairline)
                )

                HStack(spacing: StillTheme.Spacing.xxs) {
                    Text(scene.name)
                        .font(StillTypography.bodyEmphasis)
                        .foregroundStyle(StillTheme.textPrimary)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(StillTypography.caption.weight(.semibold))
                            .foregroundStyle(StillTheme.accent)
                    }
                }
                Text(isUnlocked ? scene.summary : unlockText)
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scene.name)
        .accessibilityValue(isUnlocked ? (isSelected ? "Selected. \(scene.summary)" : scene.summary) : unlockText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var unlockText: String {
        let needed = scene.unlockRule.requiredSessions
        return "Opens at \(needed) completed sessions · \(remaining) to go"
    }
}

#Preview("Scenes") {
    NavigationStack {
        SceneCollectionView()
    }
    .environment(PreviewSupport.appState(populated: true))
}
