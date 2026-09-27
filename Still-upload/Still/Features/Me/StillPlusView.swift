import SwiftUI

/// StoreKit-backed subscription surface. Until the products are actually
/// supplied by StoreKit, this stays informational rather than offering a
/// purchase or restore action that cannot succeed.
struct StillPlusView: View {
    @Environment(AppState.self) private var appState
    @State private var products: [SupporterProduct] = []
    @State private var message: String?

    private var canPurchase: Bool {
        !products.isEmpty && !appState.hasStillPlus
    }

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                        Text("STILL+")
                            .font(StillTypography.caption)
                            .tracking(1.3)
                            .foregroundStyle(StillTheme.textTertiary)
                        Text(appState.hasStillPlus ? "Still+ is active" : "A little more Still")
                            .font(StillTypography.display)
                            .foregroundStyle(StillTheme.textPrimary)
                        Text("Focus, tasks, local data, and every room earned by using Still stay free.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    benefit("creditcard", "Branded Still Card", "If a physical Still Card becomes available, it will be a subscriber benefit. Any compatible writable NFC tag can be set up free today.")
                    benefit("sparkles", "More rooms", "Three permanent original room variations.")
                    benefit("paintpalette", "Alternate cat coats", "Cosmetic coat choices for your room companion.")
                    benefit("wand.and.stars", "Future subscriber tools", "New optional tools, without ads, streak pressure, or a feed.")

                    if appState.hasStillPlus {
                        Label("Your Still+ StoreKit entitlement is active on this device.", systemImage: "checkmark.circle.fill")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.accent)
                            .padding(StillTheme.Spacing.m)
                            .stillGlass()
                    } else if canPurchase {
                        purchaseControls
                    } else {
                        QuietNote(
                            text: "Still+ is not available in this build yet. It will return after its App Store subscription products are set up.",
                            symbol: "clock"
                        )
                    }

                    if let message {
                        Text(message)
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                    if canPurchase || appState.hasStillPlus {
                        Text("You can manage or cancel a subscription in Apple Account settings. No cancellation penalty, no lost focus history.")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textTertiary)
                    }
                }
                .padding(StillTheme.Spacing.screen)
            }
            .stillScrollableViewport(reservingFloatingTabBar: false)
        }
        .navigationTitle("Still+")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.container.purchases.loadProducts()
            products = appState.container.purchases.products
        }
    }

    private var purchaseControls: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            ForEach(products) { product in
                Button("Start Still+ · \(product.displayPrice)") {
                    purchase(product)
                }
                .buttonStyle(QuietPrimaryButtonStyle())
            }
            Button("Restore purchases") { restore() }
                .buttonStyle(QuietSecondaryButtonStyle())
            Text("Renews unless cancelled in your Apple Account. StoreKit handles payment; Still does not see your payment details.")
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textSecondary)
        }
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(StillTheme.accent)
                .frame(width: 28, height: 28)
                .background(StillTheme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(StillTypography.bodyEmphasis).foregroundStyle(StillTheme.textPrimary)
                Text(detail).font(StillTypography.footnote).foregroundStyle(StillTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .stillInsetRow(verticalPadding: StillTheme.Spacing.s)
    }

    private func purchase(_ product: SupporterProduct) {
        Task { @MainActor in
            let outcome = await appState.container.purchases.purchase(productID: product.id)
            present(outcome)
        }
    }

    private func restore() {
        Task { @MainActor in
            present(await appState.container.purchases.restorePurchases())
        }
    }

    private func present(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .purchased: message = appState.container.purchases.isStandIn ? "Local StoreKit test entitlement is active. No production payment was made." : "Still+ is active."
        case .pending: message = "StoreKit says this subscription is pending."
        case .cancelled: message = nil
        case .unavailable(let detail), .failed(let detail): message = detail
        }
    }
}

#Preview("Still Plus") {
    NavigationStack { StillPlusView() }
        .environment(PreviewSupport.appState(populated: true))
}
