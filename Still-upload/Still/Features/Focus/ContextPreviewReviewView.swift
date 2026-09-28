import SwiftUI

/// DEBUG review surface for the visual previews used by long-press menus.
/// It is intentionally not linked from the customer interface; normal people
/// discover these treatments by holding their target, not by opening a guide.
struct ContextPreviewReviewView: View {
    private let columns = [GridItem(.flexible(), spacing: StillTheme.Spacing.s), GridItem(.flexible(), spacing: StillTheme.Spacing.s)]

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Long-press previews")
                            .font(StillTypography.display)
                            .foregroundStyle(StillTheme.textPrimary)
                        Text("Review-only catalogue of the contextual treatments available throughout Still.")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    LazyVGrid(columns: columns, spacing: StillTheme.Spacing.s) {
                        ContextPreviewTile(icon: "checklist", title: "Task", detail: "Details, next focus, delete")
                        ContextPreviewTile(icon: "lamp.desk", title: "Room object", detail: "A named room destination")
                        ContextPreviewTile(icon: "cup.and.saucer", title: "Break activity", detail: "A finite reset preview")
                        ContextPreviewTile(icon: "square.grid.2x2", title: "Scene", detail: "Room thumbnail and selection")
                        ContextPreviewTile(icon: "waveform", title: "Sound layer", detail: "Volume, mute, availability")
                        ContextPreviewTile(icon: "chart.bar", title: "Statistic", detail: "Local focus history")
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
            .stillScrollableViewport()
        }
        .navigationTitle("Interaction previews")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct ContextPreviewTile: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            Image(systemName: icon)
                .font(StillTypography.title2)
                .foregroundStyle(StillTheme.accent)
                .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                .background(StillTheme.accentSoft, in: Circle())
            Text(title)
                .font(StillTypography.bodyEmphasis)
                .foregroundStyle(StillTheme.textPrimary)
            Text(detail)
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .padding(StillTheme.Spacing.m)
        .background(StillTheme.surface, in: RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous).strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline))
        .accessibilityElement(children: .combine)
    }
}
