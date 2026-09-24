import SwiftUI
import UIKit

/// The environmental treatment for a Still screen. Focus deliberately uses a
/// quieter violet field instead of the current time-of-day colors.
enum StillDayPhase: String, CaseIterable, Hashable, Codable {
    case morning
    case afternoon
    case dusk
    case night
    case focus

    static func automatic(date: Date = .now, colorScheme: ColorScheme) -> StillDayPhase {
        if colorScheme == .dark { return .night }
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        switch hour {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<20: return .dusk
        default: return .night
        }
    }

    var ink: Color {
        switch self {
        case .morning, .afternoon: return Color(hex: 0x2E2530)
        case .dusk: return Color(hex: 0x2A1E2C)
        case .night, .focus: return Color(hex: 0xF5EEF8)
        }
    }

    var secondaryInk: Color {
        switch self {
        case .morning, .afternoon: return Color(hex: 0x4F4651, opacity: 0.82)
        case .dusk: return Color(hex: 0x49394B, opacity: 0.84)
        case .night, .focus: return Color(hex: 0xF5EEF8, opacity: 0.72)
        }
    }

    var glassFill: Color {
        switch self {
        case .morning, .afternoon, .dusk: return .white.opacity(0.46)
        case .night, .focus: return .white.opacity(0.08)
        }
    }

    var glassBorder: Color {
        switch self {
        case .morning, .afternoon, .dusk: return .white.opacity(0.75)
        case .night, .focus: return .white.opacity(0.16)
        }
    }

    var accent: Color {
        switch self {
        case .night, .focus: return Color(hex: 0x8FDCC0)
        case .morning, .afternoon, .dusk: return Color(hex: 0x3E8F74)
        }
    }

    var roomHalo: Color {
        switch self {
        case .night, .focus: return Color(hex: 0xFFC478, opacity: 0.75)
        case .morning, .afternoon, .dusk: return Color(hex: 0xFFDEAA, opacity: 0.88)
        }
    }

    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .morning:
            colors = [Color(hex: 0xF9D6C2), Color(hex: 0xF7E8DA), Color(hex: 0xD4E7F0)]
        case .afternoon:
            colors = [Color(hex: 0xC9EADC), Color(hex: 0xEAF3EB), Color(hex: 0xD6E6F6)]
        case .dusk:
            colors = [Color(hex: 0xF3B39C), Color(hex: 0xDDA8C2), Color(hex: 0x9C92CC)]
        case .night:
            colors = [Color(hex: 0x1C2244), Color(hex: 0x2A2556), Color(hex: 0x3A2C5C)]
        case .focus:
            colors = [Color(hex: 0x3B2E52), Color(hex: 0x1D1B30), Color(hex: 0x121221)]
        }
        return LinearGradient(colors: colors, startPoint: .topTrailing, endPoint: .bottomLeading)
    }
}

private struct StillDayPhaseKey: EnvironmentKey {
    static let defaultValue: StillDayPhase? = nil
}

extension EnvironmentValues {
    /// The phase resolved by the nearest `StillScreen`. Components fall back to
    /// the clock and color scheme when they are presented on their own.
    var stillDayPhase: StillDayPhase? {
        get { self[StillDayPhaseKey.self] }
        set { self[StillDayPhaseKey.self] = newValue }
    }
}

/// Semantic design tokens. Feature views use these names, never raw values.
enum StillTheme {
    /// Raw palette. Warm paper instead of white, navy-charcoal instead of black.
    enum Palette {
        static let paper = Color(hex: 0xF7E8DA)
        static let paperRaised = Color.white.opacity(0.46)
        static let paperSunken = Color.white.opacity(0.24)
        static let ink = Color.dynamic(light: 0x2E2530, dark: 0xF5EEF8)
        static let inkSecondary = Color.dynamic(light: 0x4F4651, dark: 0xD9D0DE)
        static let inkTertiary = Color.dynamic(light: 0x786D78, dark: 0xB9ADBF)
        static let hairline = Color.dynamic(light: 0xFFFFFF, dark: 0x6A607A).opacity(0.72)

        static let sage = Color(hex: 0x3E8F74)
        static let sageSoft = Color(hex: 0xA6D7C4, opacity: 0.48)
        static let dustyBlue = Color(hex: 0x759FC0)
        static let dustyBlueSoft = Color(hex: 0xC7E0F0, opacity: 0.66)
        static let peach = Color(hex: 0xE8A383)
        static let peachSoft = Color(hex: 0xF8D0C0, opacity: 0.62)
        static let cream = Color(hex: 0xFFF7EA)
        static let rose = Color(hex: 0xD9705F)
        static let roseSoft = Color(hex: 0xF4C4BD, opacity: 0.66)
        static let butter = Color(hex: 0xE6BF70)
        static let butterSoft = Color(hex: 0xF7E5AB, opacity: 0.62)

        /// Fixed tones for text over pixel scenes (scenes are always dusky).
        static let sceneText = Color(hex: 0xF5EEF8)
        static let sceneTextSecondary = Color(hex: 0xF5EEF8, opacity: 0.78)
        static let navyShadow = Color(hex: 0x1D1B30)
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
    static let accent = Color.dynamic(light: 0x3E8F74, dark: 0x8FDCC0)
    static let accentSoft = Palette.sageSoft
    static let onAccent = Color(hex: 0x3A2A22)
    /// Gentle attention (e.g. a Sudoku conflict). Never alarm red.
    static let attention = Palette.rose
    static let attentionSoft = Palette.roseSoft
    static let highlight = Palette.butter
    static let highlightSoft = Palette.butterSoft
    static let calm = Palette.dustyBlue
    static let calmSoft = Palette.dustyBlueSoft
    static let warm = Palette.peach
    static let warmSoft = Palette.peachSoft
    static let litButtonTop = Color(hex: 0xFFF7EA)
    static let litButtonBottom = Color(hex: 0xF7DDBB)

    static func primaryText(for phase: StillDayPhase) -> Color { phase.ink }
    static func secondaryText(for phase: StillDayPhase) -> Color { phase.secondaryInk }

    static func tertiaryText(for phase: StillDayPhase) -> Color {
        switch phase {
        case .night, .focus: return phase.ink.opacity(0.54)
        case .morning, .afternoon, .dusk: return phase.ink.opacity(0.58)
        }
    }

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

    /// Insets owned by the shared scroll viewport rather than individual
    /// screens. These values deliberately reserve the floating navigation
    /// capsule and its shadow while allowing content to use the system's
    /// actual safe-area height on every phone size.
    enum Viewport {
        static let statusBarBreathingRoom: CGFloat = 4
        static let standardBottomClearance: CGFloat = Spacing.m
        static let floatingTabBarClearance: CGFloat = 88
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 20
        static let large: CGFloat = 28
        static let scene: CGFloat = 30
        static let home: CGFloat = 30
        static let focusSlab: CGFloat = 34
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let emphasis: CGFloat = 1.5
    }

    enum Shadow {
        static let color = Color(hex: 0x38274A, opacity: 0.12)
        static let radius: CGFloat = 18
        static let y: CGFloat = 8
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
