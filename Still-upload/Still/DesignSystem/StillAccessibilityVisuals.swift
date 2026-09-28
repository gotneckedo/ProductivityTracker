import SwiftUI

private struct StillIncreaseContrastOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

private struct StillBoldTextOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// CI-only supplements to the system accessibility environments. They are
    /// false in production, where iOS remains the sole authority for both
    /// Increase Contrast and Bold Text.
    var stillIncreaseContrastOverride: Bool {
        get { self[StillIncreaseContrastOverrideKey.self] }
        set { self[StillIncreaseContrastOverrideKey.self] = newValue }
    }

    var stillBoldTextOverride: Bool {
        get { self[StillBoldTextOverrideKey.self] }
        set { self[StillBoldTextOverrideKey.self] = newValue }
    }
}
