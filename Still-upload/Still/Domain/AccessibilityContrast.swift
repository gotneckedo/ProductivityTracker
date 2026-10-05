import Foundation

/// sRGB contrast helpers and the small semantic palette used where Still renders
/// readable text or a meaning-bearing symbol. Keeping this Foundation-only lets
/// the same AA checks run in the Linux package suite and the iOS app target.
enum AccessibilityContrast {
    static let normalTextMinimum = 4.5

    static func ratio(foreground: UInt32, background: UInt32) -> Double {
        let foregroundLuminance = relativeLuminance(foreground)
        let backgroundLuminance = relativeLuminance(background)
        return (max(foregroundLuminance, backgroundLuminance) + 0.05)
            / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    static func meetsNormalTextAA(foreground: UInt32, background: UInt32) -> Bool {
        ratio(foreground: foreground, background: background) >= normalTextMinimum
    }

    private static func relativeLuminance(_ color: UInt32) -> Double {
        let red = channel(color, shift: 16)
        let green = channel(color, shift: 8)
        let blue = channel(color, shift: 0)
        return 0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    private static func channel(_ color: UInt32, shift: UInt32) -> Double {
        Double((color >> shift) & 0xFF) / 255
    }

    private static func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

/// Opaque foreground colors that must remain readable on Still's light and dark
/// fields. Pastel variants remain fill-only and are intentionally kept out of
/// this set so a decorative color cannot quietly become body text.
enum StillAccessibleColorToken {
    // Light page and raised surfaces.
    static let lightPaper: UInt32 = 0xFAF6F0
    static let lightRaisedSurface: UInt32 = 0xFFFFFF
    static let lockedSceneSurface: UInt32 = 0xDCECF0

    static let lightInk: UInt32 = 0x2E2530
    static let lightSecondary: UInt32 = 0x4F4651
    static let lightTertiary: UInt32 = 0x665B67
    static let lightAccent: UInt32 = 0x29735B
    static let lightCalm: UInt32 = 0x38638E
    static let lightWarm: UInt32 = 0x7B412D
    static let lightAttention: UInt32 = 0x82372F

    // The focus/night field is the darkest representative background in the
    // app's dark gradients; passing here also covers the lighter stop values.
    static let darkFocusField: UInt32 = 0x1D1B30
    static let darkInk: UInt32 = 0xF5EEF8
    static let darkSecondary: UInt32 = 0xD9D0DE
    static let darkTertiary: UInt32 = 0xB9ADBF
    static let darkAccent: UInt32 = 0x8FDCC0
    static let darkCalm: UInt32 = 0xA9CDEA
    static let darkWarm: UInt32 = 0xFFD0B8
    static let darkAttention: UInt32 = 0xF2A29A
}
