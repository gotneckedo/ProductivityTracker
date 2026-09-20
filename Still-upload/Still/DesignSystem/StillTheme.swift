import SwiftUI
import UIKit

/// Semantic design tokens. Feature views use these names, never raw values.
enum StillTheme {
    /// Raw palette. Warm paper instead of white, navy-charcoal instead of black.
    enum Palette {
        static let paper = Color.dynamic(light: 0xF7F2EA, dark: 0x1B1F2B)
        static let paperRaised = Color.dynamic(light: 0xFCF9F4, dark: 0x232837)
        static let paperSunken = Color.dynamic(light: 0xEFE8DC, dark: 0x161A24)
        static let ink = Color.dynamic(light: 0x2B3140, dark: 0xECE6DC)
        static let inkSecondary = Color.dynamic(light: 0x5B6172, dark: 0xB9B3A9)
        static let inkTertiary = Color.dynamic(light: 0x7F8492, dark: 0x8D909B)
        static let hairline = Color.dynamic(light: 0xE4DCCF, dark: 0x343A4A)

        static let sage = Color.dynamic(light: 0x8FAF8A, dark: 0x9DBB98)
        static let sageSoft = Color.dynamic(light: 0xE0EADB, dark: 0x2E3B31)
        static let dustyBlue = Color.dynamic(light: 0x8FA7BF, dark: 0x9FB5CB)
        static let dustyBlueSoft = Color.dynamic(light: 0xDEE6EE, dark: 0x283243)
        static let peach = Color.dynamic(light: 0xECB597, dark: 0xE6B397)
        static let peachSoft = Color.dynamic(light: 0xF8E4D8, dark: 0x3C2F29)
        static let cream = Color.dynamic(light: 0xFBF1DC, dark: 0x2E2A22)
        static let rose = Color.dynamic(light: 0xD39AA0, dark: 0xD8A4A9)
        static let roseSoft = Color.dynamic(light: 0xF5E0E1, dark: 0x3A2B2F)
        static let butter = Color.dynamic(light: 0xE3C87E, dark: 0xE0C888)
        static let butterSoft = Color.dynamic(light: 0xF7EDCC, dark: 0x383324)

        /// Fixed tones for text over pixel scenes (scenes are always dusky).
        static let sceneText = Color(hex: 0xFBF1DC)
        static let sceneTextSecondary = Color(hex: 0xFBF1DC, opacity: 0.78)
        static let navyShadow = Color(hex: 0x1F2537)
    }

    // MARK: Semantic colors

    static let background = Palette.paper
    static let surface = Palette.paperRaised
    static let surfaceSunken = Palette.paperSunken
    static let textPrimary = Palette.ink
    static let textSecondary = Palette.inkSecondary
    static let textTertiary = Palette.inkTertiary
    static let border = Palette.hairline

    /// Primary action fill. Paired with `onAccent` text.
    static let accent = Palette.sage
    static let accentSoft = Palette.sageSoft
    static let onAccent = Color(hex: 0x23291F)
    /// Gentle attention (e.g. a Sudoku conflict). Never alarm red.
    static let attention = Palette.rose
    static let attentionSoft = Palette.roseSoft
    static let highlight = Palette.butter
    static let highlightSoft = Palette.butterSoft
    static let calm = Palette.dustyBlue
    static let calmSoft = Palette.dustyBlueSoft
    static let warm = Palette.peach
    static let warmSoft = Palette.peachSoft

    static func categoryTint(_ category: ActivityCategory) -> Color {
        switch category {
        case .puzzle: return Palette.dustyBlue
        case .quiet: return Palette.butter
        case .reset: return Palette.sage
        }
    }

    static func categorySoftTint(_ category: ActivityCategory) -> Color {
        switch category {
        case .puzzle: return Palette.dustyBlueSoft
        case .quiet: return Palette.butterSoft
        case .reset: return Palette.sageSoft
        }
    }

    // MARK: Layout tokens

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        /// Horizontal screen margin.
        static let screen: CGFloat = 20
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 26
        static let scene: CGFloat = 30
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let emphasis: CGFloat = 1.5
    }

    enum Shadow {
        static let color = Color(hex: 0x1F2537, opacity: 0.06)
        static let radius: CGFloat = 14
        static let y: CGFloat = 4
    }

    /// Minimum comfortable touch target.
    static let minimumTapSize: CGFloat = 44
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(_ rgb: RGBColor) {
        self.init(hex: rgb.hex)
    }

    /// A color that follows light and dark appearance.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
