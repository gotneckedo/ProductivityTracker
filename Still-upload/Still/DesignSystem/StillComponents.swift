import SwiftUI

// Shared primitives. Features compose these instead of inventing new styles.

// MARK: - Screen & surfaces

/// The warm paper background every screen sits on.
struct StillScreen<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            StillTheme.background.ignoresSafeArea()
            content
        }
    }
}

/// A large rounded card with a fine low-contrast border and restrained shadow.
struct StillCard<Content: View>: View {
    var padding: CGFloat = StillTheme.Spacing.m
    var tint: Color = StillTheme.surface
    private let content: Content

    init(padding: CGFloat = StillTheme.Spacing.m, tint: Color = StillTheme.surface, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous)
                    .strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline)
            )
            .shadow(color: StillTheme.Shadow.color, radius: StillTheme.Shadow.radius, x: 0, y: StillTheme.Shadow.y)
    }
}

// MARK: - Buttons

/// The one prominent action on a screen.
struct QuietPrimaryButtonStyle: ButtonStyle {
    var fill: Color = StillTheme.accent
    var foreground: Color = StillTheme.onAccent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StillTypography.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, StillTheme.Spacing.m)
            .background(
                Capsule(style: .continuous)
                    .fill(fill.opacity(isEnabled ? 1 : 0.45))
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .contentShape(Capsule())
    }
}

/// A supporting action: outlined, never louder than the primary.
struct QuietSecondaryButtonStyle: ButtonStyle {
    var foreground: Color = StillTheme.textPrimary
    var border: Color = StillTheme.border

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StillTypography.callout.weight(.medium))
            .foregroundStyle(foreground)
            .frame(minHeight: StillTheme.minimumTapSize)
            .padding(.horizontal, StillTheme.Spacing.m)
            .background(
                Capsule(style: .continuous)
                    .strokeBorder(border, lineWidth: StillTheme.Stroke.hairline)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// Plain text action, e.g. "End session".
struct QuietTextButtonStyle: ButtonStyle {
    var foreground: Color = StillTheme.textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StillTypography.callout)
            .foregroundStyle(foreground)
            .frame(minHeight: StillTheme.minimumTapSize)
            .padding(.horizontal, StillTheme.Spacing.xs)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

// MARK: - Text

struct SectionHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
            Text(title)
                .font(StillTypography.headline)
                .foregroundStyle(StillTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A quiet number with a label. Not a dashboard tile.
struct SubtleMetric: View {
    let value: String
    let label: String
    var accessibilityValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
            Text(value)
                .font(StillTypography.metric)
                .foregroundStyle(StillTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue ?? value)
    }
}

// MARK: - Pixel motifs

/// A row of small squares used as a divider.
struct PixelDivider: View {
    var color: Color = StillTheme.border

    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.width / 8))
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { _ in
                    Rectangle().fill(color).frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// Progress drawn as small squares that fill in. Quieter than a ring.
struct PixelProgressRow: View {
    let progress: Double
    var count: Int = 20
    var filled: Color = StillTheme.accent
    var empty: Color = StillTheme.border

    var body: some View {
        let lit = Int((min(max(progress, 0), 1) * Double(count)).rounded(.down))
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(index < lit ? filled : empty)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Timer

/// The large time display. Remaining time for fixed phases, elapsed for count-up.
struct SessionTimerFace: View {
    enum Surface {
        case paper
        case scene
    }

    let time: String
    let caption: String
    let progress: Double?
    let isPaused: Bool
    let accessibilityText: String
    var surface: Surface = .paper

    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 76

    private var primary: Color {
        surface == .scene ? StillTheme.Palette.sceneText : StillTheme.textPrimary
    }

    private var secondary: Color {
        surface == .scene ? StillTheme.Palette.sceneTextSecondary : StillTheme.textSecondary
    }

    var body: some View {
        VStack(spacing: StillTheme.Spacing.s) {
            Text(caption)
                .font(StillTypography.subheadline.weight(.medium))
                .foregroundStyle(secondary)
                .textCase(.uppercase)
                .tracking(1.2)
            Text(time)
                .font(StillTypography.timer(size: timerSize))
                .foregroundStyle(primary)
                .opacity(isPaused ? 0.55 : 1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            if let progress {
                PixelProgressRow(
                    progress: progress,
                    filled: surface == .scene ? StillTheme.Palette.sceneText : StillTheme.accent,
                    empty: surface == .scene ? StillTheme.Palette.sceneText.opacity(0.22) : StillTheme.border
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue(accessibilityText)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Selection

/// An accessible segmented selector with pill styling.
struct SelectionPill<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: StillTheme.Spacing.xxs) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(StillTypography.callout.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? StillTheme.textPrimary : StillTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? StillTheme.surface : Color.clear)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(isSelected ? StillTheme.border : Color.clear, lineWidth: StillTheme.Stroke.hairline)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(StillTheme.Spacing.xxs)
        .background(Capsule(style: .continuous).fill(StillTheme.surfaceSunken))
    }
}

// MARK: - Activities

struct ActivityTile: View {
    let activity: BreakActivity
    var isDoneToday: Bool = false
    var style: Style = .row

    enum Style {
        /// Full-width row on the shelf.
        case row
        /// Compact card for the three suggestions.
        case suggestion
    }

    var body: some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Image(systemName: activity.symbolName)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(StillTheme.textPrimary)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: StillTheme.Radius.small, style: .continuous)
                        .fill(StillTheme.categorySoftTint(activity.category))
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                Text(style == .row ? activity.summary : "About \(activity.estimatedMinutes) min")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: StillTheme.Spacing.xs)
            VStack(alignment: .trailing, spacing: 2) {
                if style == .row {
                    Text("\(activity.estimatedMinutes) min")
                        .font(StillTypography.footnote.monospacedDigit())
                        .foregroundStyle(StillTheme.textTertiary)
                }
                if isDoneToday {
                    Image(systemName: "checkmark")
                        .font(StillTypography.caption.weight(.semibold))
                        .foregroundStyle(StillTheme.accent)
                }
            }
        }
        .padding(StillTheme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                .fill(StillTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                .strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline)
        )
        .contentShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activity.name)
        .accessibilityValue("About \(activity.estimatedMinutes) minutes. \(activity.summary)\(isDoneToday ? " Done today." : "")")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Empty & settings

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: StillTheme.Spacing.s) {
            Image(systemName: symbol)
                .font(.system(.title, design: .rounded))
                .foregroundStyle(StillTheme.textTertiary)
                .accessibilityHidden(true)
            Text(title)
                .font(StillTypography.headline)
                .foregroundStyle(StillTheme.textPrimary)
            Text(message)
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StillTheme.Spacing.l)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A settings row. Use as the label of a Button or NavigationLink.
struct SettingRow: View {
    let symbol: String
    let title: String
    var value: String?
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Image(systemName: symbol)
                .font(StillTypography.body)
                .foregroundStyle(StillTheme.textSecondary)
                .frame(width: 26)
                .accessibilityHidden(true)
            Text(title)
                .font(StillTypography.body)
                .foregroundStyle(StillTheme.textPrimary)
            Spacer(minLength: StillTheme.Spacing.xs)
            if let value {
                Text(value)
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(StillTypography.footnote.weight(.semibold))
                    .foregroundStyle(StillTheme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: StillTheme.minimumTapSize)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A calm inline note, e.g. "Ambient audio is ready when sound files are added."
struct QuietNote: View {
    let text: String
    var symbol: String = "info.circle"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StillTheme.Spacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(StillTheme.textTertiary)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(StillTypography.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
