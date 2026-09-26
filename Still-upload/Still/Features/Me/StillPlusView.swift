import SwiftUI

/// StoreKit-backed subscription surface. It never suggests that focus, tasks,
/// privacy, or session-earned rooms are paywalled.
struct StillPlusView: View {
    @Environment(AppState.self) private var appState
    @State private var products: [SupporterProduct] = []
    @State private var message: String?

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

                    benefit("wave.3.right", "Focus Card access", "Set up a physical NFC card for a favorite focus preset.")
                    benefit("sparkles", "Seasonal rooms", "Optional original room variations and extra palettes.")
                    benefit("paintpalette", "Future subscriber tools", "New optional tools, without ads, streak pressure, or a feed.")

                    if appState.hasStillPlus {
                        Label("Your Still+ StoreKit entitlement is active on this device.", systemImage: "checkmark.circle.fill")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.accent)
                            .padding(StillTheme.Spacing.m)
                            .stillGlass()
                    } else if let product = products.first {
                        Button("Start Still+ · \(product.displayPrice)") {
                            purchase(product)
                        }
                        .buttonStyle(QuietPrimaryButtonStyle())
                        Text("Renews monthly unless cancelled in your Apple Account. StoreKit handles payment; Still does not see your payment details.")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    } else {
                        QuietNote(text: "Still+ products are not available yet. Add the subscription in App Store Connect before offering it outside the local StoreKit test configuration.")
                    }

                    Button("Restore purchases") { restore() }
                        .buttonStyle(QuietSecondaryButtonStyle())
                    if let message {
                        Text(message)
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                    Text("You can manage or cancel a subscription in Apple Account settings. No cancellation penalty, no lost focus history.")
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textTertiary)
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
        .padding(StillTheme.Spacing.m)
        .stillGlass(radius: StillTheme.Radius.medium)
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
