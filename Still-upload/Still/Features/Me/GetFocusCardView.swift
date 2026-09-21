import SwiftUI

struct GetFocusCardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Get a card")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        PreviewTag()
                    }

                    BrandedFocusCardArtwork(presetName: appState.currentPreset.name)
                        .aspectRatio(1.6, contentMode: .fit)

                    StillCard {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            SectionHeader(title: "What the card does")
                            Text("A Focus Card is a reusable NFC tag containing one Still link. Tapping it can open a preset; it does not contain your tasks or study history.")
                                .font(StillTypography.callout)
                                .foregroundStyle(StillTheme.textSecondary)
                            PixelDivider()
                            Text("This screen is a design preview, not a shop. Still cannot take payment or ship a card. You can set up any compatible writable NFC tag from the Focus Card screen today.")
                                .font(StillTypography.footnote)
                                .foregroundStyle(StillTheme.textSecondary)
                        }
                    }

                    Button("Set up a compatible tag") {
                        appState.router.go(to: .nfcSetup)
                    }
                    .buttonStyle(QuietSecondaryButtonStyle())

                    if let offer = appState.container.focusCardOffering.offer {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                            Link("Open placeholder setup page", destination: offer.setupURL)
                                .buttonStyle(QuietPrimaryButtonStyle())
                            Text(offer.setupURL.absoluteString)
                                .font(StillTypography.caption.monospaced())
                                .foregroundStyle(StillTheme.textTertiary)
                                .textSelection(.enabled)
                            Text("The reserved .example address is intentionally not a live storefront.")
                                .font(StillTypography.footnote)
                                .foregroundStyle(StillTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

/// Code-drawn pixel card so artwork can be judged now and swapped for a final
/// asset later without changing the NFC or deep-link behavior.
struct BrandedFocusCardArtwork: View {
    let presetName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x232B45), Color(hex: 0x39496B)], startPoint: .topLeading, endPoint: .bottomTrailing))
            pixelStars
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                HStack {
                    Text("STILL")
                        .font(StillTypography.headline.monospaced().weight(.bold))
                        .tracking(3)
                    Spacer()
                    Image(systemName: "wave.3.right")
                        .font(StillTypography.title3)
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FOCUS CARD")
                            .font(StillTypography.caption.monospaced().weight(.semibold))
                            .tracking(1.2)
                        Text(presetName)
                            .font(StillTypography.title3)
                    }
                    Spacer()
                    pixelPlant
                }
            }
            .foregroundStyle(Color(hex: 0xFBF1DC))
            .padding(StillTheme.Spacing.l)
        }
        .overlay(RoundedRectangle(cornerRadius: StillTheme.Radius.large).strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
        .shadow(color: StillTheme.Shadow.color, radius: 18, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A navy pixel-art Still Focus Card for the \(presetName) preset")
    }

    private var pixelStars: some View {
        GeometryReader { proxy in
            let points: [(CGFloat, CGFloat)] = [(0.14, 0.24), (0.76, 0.22), (0.86, 0.48), (0.54, 0.32)]
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Rectangle()
                    .fill(Color(hex: 0xF2C98B).opacity(0.8))
                    .frame(width: 5, height: 5)
                    .position(x: proxy.size.width * point.0, y: proxy.size.height * point.1)
            }
        }
        .accessibilityHidden(true)
    }

    private var pixelPlant: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(Color(hex: 0x8FAF8A)).frame(width: 12, height: 8)
                Rectangle().fill(Color(hex: 0xA7C69F)).frame(width: 8, height: 12)
            }
            Rectangle().fill(Color(hex: 0xC98E7A)).frame(width: 24, height: 16)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Get a card") {
    NavigationStack { GetFocusCardView() }
        .environment(PreviewSupport.appState())
}
