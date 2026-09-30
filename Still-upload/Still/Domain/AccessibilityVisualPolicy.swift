import Foundation

/// Platform-neutral rules for Still's custom surfaces when a person asks iOS
/// for stronger visual separation. The SwiftUI layer supplies the actual colors
/// and material; tests pin the behavioral contract without importing SwiftUI.
enum AccessibilityVisualPolicy {
    static let normalBorderWidth: Double = 1
    static let increasedContrastBorderWidth: Double = 1.5

    static func usesOpaqueControlSurface(
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) -> Bool {
        reduceTransparency || increasedContrast
    }

    static func borderWidth(increasedContrast: Bool) -> Double {
        increasedContrast ? increasedContrastBorderWidth : normalBorderWidth
    }

    static func shouldRequestBoldLegibility(
        systemBoldText: Bool,
        proofOverride: Bool
    ) -> Bool {
        systemBoldText || proofOverride
    }
}
