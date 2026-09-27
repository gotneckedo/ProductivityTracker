import SwiftUI

/// Scenes and how they open. Session-earned rooms are always free; the three
/// permanent extra rooms use the clearly labelled Still+ entitlement.
struct SceneCollectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var purchaseMessage: String?
    @State private var stillPlusProducts: [SupporterProduct] = []

    private var canPurchase: Bool {
        !stillPlusProducts.isEmpty && !appState.hasStillPlus
    }

    /// The collection stays inside the screen's horizontal padding. Flexible
    /// columns, rather than card widths, leave equal space on both edges on
    /// every iPhone width and Dynamic Type size.
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        let preset = appState.currentPreset
        StillScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Scenes")
                            .font(StillTypography.display)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
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
                    Color.clear.frame(height: 1).id("scenes-midpoint")

                    extraRoomsSection(preset: preset)
                    stillPlusSection
                    Color.clear.frame(height: 1).id("scenes-bottom")
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                }
                .stillScrollableViewport()
                .onAppear {
                    #if DEBUG || STILL_PROOF
                    if DemoLaunch.shouldScrollToBottom("scenes-all") {
                        DispatchQueue.main.async { proxy.scrollTo("scenes-bottom", anchor: .bottom) }
                    } else if DemoLaunch.requestedScreen == "scenes-extra" || DemoLaunch.requestedScreen == "release-locked-room" {
                        DispatchQueue.main.async { proxy.scrollTo("extra-rooms", anchor: .top) }
                    } else if DemoLaunch.shouldScrollToMidpoint("scenes") {
                        DispatchQueue.main.async { proxy.scrollTo("scenes-midpoint", anchor: .top) }
                    }
                    #endif
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { appState.acknowledgeUnlockedScenes() }
        .task {
            await appState.container.purchases.loadProducts()
            refreshPurchaseState()
        }
    }

    private func extraRoomsSection(preset: FocusPreset) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            HStack {
                SectionHeader(
                    title: "More rooms"
                )
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SceneCatalog.extraRooms) { scene in
                    let entitled = appState.isUnlocked(scene)
                    SceneCard(
                        scene: scene,
                        isUnlocked: entitled,
                        isSelected: preset.sceneID == scene.id && preset.renderMode == .scene,
                        remaining: 0,
                        lockedText: "Still+ room"
                    ) {
                        var edited = preset
                        edited.sceneID = scene.id
                        edited.renderMode = .scene
                        appState.savePreset(edited)
                    }
                    onLocked: {
                        appState.router.go(to: .stillPlus)
                    }
                }
            }
        }
        .id("extra-rooms")
    }

    private var stillPlusSection: some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                HStack {
                    SectionHeader(title: "Still+")
                }
                if appState.hasStillPlus {
                    Text("Still+ is active on this device.")
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                } else if canPurchase {
                    ForEach(stillPlusProducts) { product in
                        Button("Start Still+ · \(product.displayPrice)") {
                            runPurchase { await appState.container.purchases.purchase(productID: product.id) }
                        }
                        .buttonStyle(QuietPrimaryButtonStyle())
                    }
                    Button("Restore purchases") {
                        runPurchase { await appState.container.purchases.restorePurchases() }
                    }
                    .buttonStyle(QuietSecondaryButtonStyle())
                } else {
                    Text("Still+ is not available in this build yet.")
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                }
                if let purchaseMessage {
                    Text(purchaseMessage)
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                }
            }
        }
    }

    private func runPurchase(_ action: @escaping () async -> PurchaseOutcome) {
        Task { @MainActor in
            let outcome = await action()
            refreshPurchaseState()
            switch outcome {
            case .purchased:
                purchaseMessage = appState.container.purchases.isStandIn
                    ? "Still+ is active for this preview."
                    : "Still+ is active."
            case .pending:
                purchaseMessage = "Purchase pending."
            case .cancelled:
                purchaseMessage = nil
            case .unavailable(let message), .failed(let message):
                purchaseMessage = message
            }
        }
    }

    @MainActor
    private func refreshPurchaseState() {
        stillPlusProducts = appState.container.purchases.products
    }
}

private struct SceneCard: View {
    let scene: SceneDefinition
    let isUnlocked: Bool
    let isSelected: Bool
    let remaining: Int
    var lockedText: String? = nil
    let onSelect: () -> Void
    var onLocked: (() -> Void)? = nil

    var body: some View {
        Group {
            if isUnlocked {
                Button(action: onSelect) { cardContent }
                    .buttonStyle(.plain)
            } else {
                Button(action: { onLocked?() }) { cardContent }
                    .buttonStyle(.plain)
                    .disabled(onLocked == nil)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scene.name)
        .accessibilityValue(isUnlocked ? (isSelected ? "Selected. \(scene.summary)" : scene.summary) : unlockText)
        .accessibilityAddTraits(isUnlocked ? (isSelected ? [.isButton, .isSelected] : .isButton) : (onLocked == nil ? [] : .isButton))
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            ZStack {
                RoomHeroView(
                    sceneName: scene.name,
                    sceneID: scene.id,
                    allowsCatInteraction: false,
                    phase: .afternoon,
                    plantStage: .full,
                    showsControls: false
                )
                .saturation(isUnlocked ? 1 : 0.22)
                .opacity(isUnlocked ? 1 : 0.68)
                if !isUnlocked {
                    Rectangle().fill(StillTheme.Palette.navyShadow.opacity(0.22))
                    Image(systemName: "lock.fill")
                        .font(StillTypography.title3)
                        .foregroundStyle(.white)
                        .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                        .background(Circle().fill(StillTheme.Palette.navyShadow.opacity(0.82)))
                }
            }
            .aspectRatio(RoomHeroView.artworkAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? StillTheme.accent : StillTheme.border, lineWidth: isSelected ? 2 : StillTheme.Stroke.hairline)
            )

            HStack(spacing: StillTheme.Spacing.xxs) {
                Text(scene.name)
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(StillTypography.caption.weight(.semibold))
                        .foregroundStyle(StillTheme.accent)
                }
            }
            Text(isUnlocked ? scene.summary : unlockText)
                .font(StillTypography.footnote.weight(isUnlocked ? .regular : .medium))
                .foregroundStyle(isUnlocked ? StillTheme.textSecondary : StillTheme.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StillTheme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                .fill(StillTheme.calmSoft.opacity(isUnlocked ? 0.64 : 0.76))
        )
        .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
    }

    private var unlockText: String {
        if let lockedText { return lockedText }
        let needed = scene.unlockRule.requiredSessions
        return "Opens at \(Copy.Count.session(needed)) · \(Copy.Count.session(remaining)) to go"
    }
}

#Preview("Scenes") {
    NavigationStack {
        SceneCollectionView()
    }
    .environment(PreviewSupport.appState(populated: true))
}
