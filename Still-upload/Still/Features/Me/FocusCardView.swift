import SwiftUI
import UIKit

/// How a physical Focus Card works, the exact links to write, and an in-app
/// simulator that runs the same route as a real tag.
struct FocusCardView: View {
    @Environment(AppState.self) private var appState
    @State private var copiedPresetID: FocusPresetID?
    #if canImport(CoreNFC) && os(iOS) && STILL_CORENFC
    @State private var writer = CoreNFCTagWriter()
    #endif

    var body: some View {
        StillScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Focus Card")
                                .font(StillTypography.title)
                                .foregroundStyle(StillTheme.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            if appState.container.flags.brandedFocusCardPreview { PreviewTag() }
                        }
                        Text(FocusCardGuide.summary)
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if appState.container.flags.brandedFocusCardPreview {
                        BrandedFocusCardArtwork(presetName: appState.currentPreset.name)
                            .aspectRatio(1.6, contentMode: .fit)
                        Button("Get a card") {
                            appState.router.go(to: .getFocusCard)
                        }
                        .buttonStyle(QuietSecondaryButtonStyle())
                        Text("Design preview only. There is no ordering or payment in Still.")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    if !appState.hasStillPlus {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            Label("Focus Card is a Still+ perk", systemImage: "lock.fill")
                                .font(StillTypography.bodyEmphasis)
                                .foregroundStyle(StillTheme.textPrimary)
                            Text("Still+ supports optional physical card access and seasonal rooms. Your regular focus timer and every session-earned room stay free.")
                                .font(StillTypography.callout)
                                .foregroundStyle(StillTheme.textSecondary)
                            Button("Explore Still+") { appState.router.go(to: .stillPlus) }
                                .buttonStyle(QuietSecondaryButtonStyle())
                        }
                        .padding(StillTheme.Spacing.m)
                        .stillGlass()
                    } else {
                    StillCard {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            ForEach(Array(FocusCardGuide.steps.enumerated()), id: \.offset) { entry in
                                HStack(alignment: .firstTextBaseline, spacing: StillTheme.Spacing.s) {
                                    Text("\(entry.offset + 1)")
                                        .font(StillTypography.footnote.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(StillTheme.textTertiary)
                                    Text(entry.element)
                                        .font(StillTypography.callout)
                                        .foregroundStyle(StillTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        SectionHeader(title: "Links and simulator", detail: "Write a link to a tag, or tap Simulate to run the same route here.")
                        ForEach(appState.presets) { preset in
                            presetCard(preset)
                        }
                    }

                    QuietNote(text: FocusCardGuide.hardwareNote)

                    let blocking = appState.container.blocking
                    StillCard(tint: StillTheme.surfaceSunken) {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                            Text(BlockingCopy.title(for: blocking.capability, isShielding: blocking.isShielding))
                                .font(StillTypography.bodyEmphasis)
                                .foregroundStyle(StillTheme.textPrimary)
                            Text(BlockingCopy.detail(for: blocking.capability))
                                .font(StillTypography.footnote)
                                .foregroundStyle(StillTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    }
                    Color.clear.frame(height: 1).id("focus-card-bottom")
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                }
                .stillScrollableViewport()
                .onAppear {
                    #if DEBUG
                    guard DemoLaunch.shouldScrollToBottom("card") else { return }
                    DispatchQueue.main.async { proxy.scrollTo("focus-card-bottom", anchor: .bottom) }
                    #endif
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func presetCard(_ preset: FocusPreset) -> some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                HStack {
                    Text(preset.name)
                        .font(StillTypography.bodyEmphasis)
                        .foregroundStyle(StillTheme.textPrimary)
                    Spacer()
                    Text(DurationSummaryText.short(preset.timer))
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                }
                Text(preset.startURL.absoluteString)
                    .font(StillTypography.footnote.monospaced())
                    .foregroundStyle(StillTheme.textSecondary)
                    .textSelection(.enabled)
                    .accessibilityLabel("Link: \(preset.startURL.absoluteString)")
                HStack(spacing: StillTheme.Spacing.s) {
                    Button(copiedPresetID == preset.id ? "Copied" : "Copy link") {
                        UIPasteboard.general.string = preset.startURL.absoluteString
                        copiedPresetID = preset.id
                    }
                    .buttonStyle(QuietSecondaryButtonStyle())
                    Button("Simulate tap") {
                        appState.simulateFocusCard(presetID: preset.id)
                    }
                    .buttonStyle(QuietSecondaryButtonStyle())
                    .accessibilityHint("Starts \(preset.name) exactly as a tag with this link would.")
                }
                if appState.container.flags.brandedFocusCardPreview {
                    Text(StillLinks.startFocusURL(presetID: preset.id).absoluteString)
                        .font(StillTypography.caption.monospaced())
                        .foregroundStyle(StillTheme.textTertiary)
                        .textSelection(.enabled)
                    Button("Simulate future universal link") {
                        appState.simulateBrandedFocusCard(presetID: preset.id)
                    }
                    .buttonStyle(QuietSecondaryButtonStyle())
                    .accessibilityHint("Tests the placeholder HTTPS link through the same deep-link parser.")
                }
                #if canImport(CoreNFC) && os(iOS) && STILL_CORENFC
                if CoreNFCTagWriter.isAvailable {
                    Button("Write to a tag") {
                        writer.write(preset.startURL) { result in
                            switch result {
                            case .written: appState.notice = StillNotice(text: "\(preset.name) is on your Focus Card.")
                            case .cancelled: break
                            default: appState.notice = StillNotice(text: "The tag wasn't written. Try holding it still near the top of your iPhone.")
                            }
                        }
                    }
                    .buttonStyle(QuietPrimaryButtonStyle())
                    .accessibilityHint("Writes this preset's link to a blank NFC tag.")
                }
                #endif
            }
        }
    }
}

#Preview("Focus Card") {
    NavigationStack {
        FocusCardView()
    }
    .environment(PreviewSupport.appState())
}
