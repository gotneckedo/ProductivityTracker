import SwiftUI
import UIKit

/// How a physical Focus Card works, the exact links to write, and an in-app
/// simulator that runs the same route as a real tag.
struct FocusCardView: View {
    @Environment(AppState.self) private var appState
    @State private var copiedPresetID: FocusPresetID?

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                        Text("Focus Card")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(FocusCardGuide.summary)
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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
