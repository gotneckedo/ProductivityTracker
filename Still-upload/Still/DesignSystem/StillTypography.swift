import SwiftUI

/// All type is defined against Dynamic Type styles so the bundled families scale.
/// Instrument Serif is reserved for editorial display moments; Outfit carries UI.
enum StillTypography {
    static let display = Font.custom("InstrumentSerif-Regular", size: 40, relativeTo: .largeTitle)
    static let hero = Font.custom("InstrumentSerif-Regular", size: 64, relativeTo: .largeTitle)
    static let title = Font.custom("InstrumentSerif-Regular", size: 26, relativeTo: .title2)
    static let title3 = Font.custom("InstrumentSerif-Regular", size: 22, relativeTo: .title3)
    static let headline = Font.custom("Outfit-SemiBold", size: 17, relativeTo: .headline)
    static let body = Font.custom("Outfit-Regular", size: 17, relativeTo: .body)
    static let bodyEmphasis = Font.custom("Outfit-Medium", size: 17, relativeTo: .body)
    static let callout = Font.custom("Outfit-Regular", size: 16, relativeTo: .callout)
    static let subheadline = Font.custom("Outfit-Medium", size: 15, relativeTo: .subheadline)
    static let footnote = Font.custom("Outfit-Regular", size: 13, relativeTo: .footnote)
    static let caption = Font.custom("Outfit-Medium", size: 12, relativeTo: .caption)
    static let metric = Font.custom("InstrumentSerif-Regular", size: 32, relativeTo: .title2)
    static let reading = Font.custom("InstrumentSerif-Regular", size: 18, relativeTo: .body)
    static let readingTitle = Font.custom("InstrumentSerif-Regular", size: 28, relativeTo: .title2)

    /// The large timer. Pair with @ScaledMetric so accessibility sizes remain legible.
    static func timer(size: CGFloat) -> Font {
        Font.custom("InstrumentSerif-Regular", size: size, relativeTo: .largeTitle).monospacedDigit()
    }
}
