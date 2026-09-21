import SwiftUI

/// Scenes and how they open. Unlock conditions are stated quietly; there is
/// no reward burst, nothing to buy, and nothing to lose.
struct SceneCollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var purchaseMessage: String?
    @State private var supporterProducts: [SupporterProduct] = []
    @State private var purchasedProductIDs: Set<String> = []

    private let columns = [GridItem(.flexible(), spacing: StillTheme.Spacing.m), GridItem(.flexible(), spacing: StillTheme.Spacing.m)]

    var body: some View {
        let preset = appState.currentPreset
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Scenes")
                            .font(StillTypography.display)
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

                    if appState.container.flags.seasonalPurchasesPreview {
                        seasonalSection(preset: preset)
                        supporterSection
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { appState.acknowledgeUnlockedScenes() }
        .task {
            guard appState.container.flags.seasonalPurchasesPreview else { return }
            await appState.container.purchases.loadProducts()
            refreshPurchaseState()
        }
    }

    private func seasonalSection(preset: FocusPreset) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            HStack {
                SectionHeader(
                    title: "Seasonal rooms",
                    detail: "Optional cosmetics only. Every scene earned from focus sessions stays free."
                )
                PreviewTag()
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: StillTheme.Spacing.l) {
                ForEach(SceneCatalog.seasonal) { scene in
                    let entitled = scene.entitlementKey.map(purchasedProductIDs.contains) ?? true
                    SceneCard(
                        scene: scene,
                        isUnlocked: entitled,
                        isSelected: preset.sceneID == scene.id && preset.renderMode == .scene,
                        remaining: 0,
                        lockedText: "Supporter cosmetic · local StoreKit preview"
                    ) {
                        guard entitled else { return }
                        var edited = preset
                        edited.sceneID = scene.id
                        edited.renderMode = .scene
                        appState.savePreset(edited)
                    }
                }
            }
        }
    }

    private var supporterSection: some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                HStack {
                    SectionHeader(title: "Supporter")
                    PreviewTag()
                }
                Text("One optional, non-consumable cosmetic pack: seasonal rooms, extra palettes, and future alternate app icons. No subscription, countdown, or limited offer.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                if purchasedProductIDs.contains(PurchaseProductCatalog.supporter) {
                    Text("Local StoreKit test entitlement is active on this device.")
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                } else if let product = supporterProducts.first {
                    Button("Test Supporter · \(product.displayPrice)") {
                        runPurchase { await appState.container.purchases.purchase(productID: product.id) }
                    }
                    .buttonStyle(QuietPrimaryButtonStyle())
                } else {
                    Text("Open this Debug scheme with StillProducts.storekit to load the local test product.")
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                }
                Button("Restore purchases") {
                    runPurchase { await appState.container.purchases.restorePurchases() }
                }
                .buttonStyle(QuietSecondaryButtonStyle())
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
                    ? "Local StoreKit test entitlement updated. No production charge was made."
                    : "Purchase restored."
            case .pending:
                purchaseMessage = "StoreKit says the test transaction is pending."
            case .cancelled:
                purchaseMessage = nil
            case .unavailable(let message), .failed(let message):
                purchaseMessage = message
            }
        }
    }

    @MainActor
    private func refreshPurchaseState() {
        supporterProducts = appState.container.purchases.products
        purchasedProductIDs = appState.container.purchases.purchasedProductIDs
    }
}

private struct SceneCard: View {
    let scene: SceneDefinition
    let isUnlocked: Bool
    let isSelected: Bool
    let remaining: Int
    var lockedText: String? = nil
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
            .padding(StillTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .stillGlass(radius: StillTheme.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? StillTheme.accent : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scene.name)
        .accessibilityValue(isUnlocked ? (isSelected ? "Selected. \(scene.summary)" : scene.summary) : unlockText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var unlockText: String {
        if let lockedText { return lockedText }
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
