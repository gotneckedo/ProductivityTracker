import SwiftUI
import WidgetKit

/// Still's widgets: a home-screen summary with one-tap start, and the
/// Lock Screen / Dynamic Island timer for a running session.
@main
struct StillWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StillFocusSummaryWidget()
        StillLiveActivityWidget()
    }
}
