import SwiftUI

private struct StillIncreaseContrastOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// CI-only supplement to the system Increase Contrast environment. It is
    /// false in production, where iOS remains the sole authority.
    var stillIncreaseContrastOverride: Bool {
        get { self[StillIncreaseContrastOverrideKey.self] }
        set { self[StillIncreaseContrastOverrideKey.self] = newValue }
    }
}
