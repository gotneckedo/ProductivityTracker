import SwiftUI

/// Marks screens or controls backed by sample/local behavior rather than a live
/// external service.
struct PreviewTag: View {
    var body: some View {
        Text("Preview")
            .font(StillTypography.caption.weight(.semibold))
            .foregroundStyle(StillTheme.textSecondary)
            .padding(.horizontal, StillTheme.Spacing.xs)
            .padding(.vertical, StillTheme.Spacing.xxs)
            .background(Capsule().fill(StillTheme.surfaceSunken))
            .overlay(Capsule().strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline))
            .accessibilityLabel("Preview feature")
    }
}
