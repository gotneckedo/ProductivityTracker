import SwiftUI

/// Text styles. Every style is built on a Dynamic Type text style so it scales.
///
/// V1 uses the rounded system face. To adopt a licensed custom font later,
/// change only this file (e.g. `Font.custom("Name", size: 17, relativeTo: .body)`).
enum StillTypography {
    static let display = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let title3 = Font.system(.title3, design: .rounded).weight(.medium)
    static let headline = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .rounded)
    static let bodyEmphasis = Font.system(.body, design: .rounded).weight(.medium)
    static let callout = Font.system(.callout, design: .rounded)
    static let subheadline = Font.system(.subheadline, design: .rounded)
    static let footnote = Font.system(.footnote, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    /// Stats and durations.
    static let metric = Font.system(.title2, design: .rounded).weight(.medium).monospacedDigit()
    /// Reading text for Short Read: a little larger, serif for long-form calm.
    static let reading = Font.system(.body, design: .serif)
    static let readingTitle = Font.system(.title2, design: .serif).weight(.semibold)

    /// The large timer. Pair with `@ScaledMetric` for the size so it scales.
    static func timer(size: CGFloat) -> Font {
        Font.system(size: size, weight: .light, design: .rounded).monospacedDigit()
    }
}
