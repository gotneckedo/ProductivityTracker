import Foundation
import Observation

/// A session whose "What instead?" screen is showing.
struct CompletionPresentation: Identifiable, Hashable {
    let sessionID: UUID
    var id: UUID { sessionID }
}

/// Owns navigation state. Views call `go(to:)`; `RouteResolver` decides the
/// tab, stack, and modal, so leaf views never make presentation decisions.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .focus
    var focusPath: [AppRoute] = []
    var breakPath: [AppRoute] = []
    var mePath: [AppRoute] = []
    var journalPath: [AppRoute] = []
    var sheet: SheetRoute? = nil
    var completion: CompletionPresentation? = nil

    let flags: FeatureFlags
    private let resolver: RouteResolver

    init(flags: FeatureFlags) {
        self.flags = flags
        self.resolver = RouteResolver(flags: flags)
    }

    var visibleTabs: [AppTab] { AppTab.visibleTabs(flags: flags) }

    func go(to route: AppRoute) {
        let destination = resolver.destination(for: route, currentTab: selectedTab)
        if let sessionID = destination.completionSessionID {
            sheet = nil
            completion = CompletionPresentation(sessionID: sessionID)
            return
        }
        completion = nil
        if let sheetRoute = destination.sheet {
            // Sheets leave the current tab and its stack untouched.
            sheet = sheetRoute
            return
        }
        sheet = nil
        selectedTab = destination.tab
        switch destination.tab {
        case .focus: focusPath = destination.stack
        case .breakShelf: breakPath = destination.stack
        case .me: mePath = destination.stack
        case .journal: journalPath = destination.stack
        }
    }

    /// Pops the Break stack back to the shelf.
    func popToShelf() {
        breakPath = []
    }

    func dismissSheet() {
        sheet = nil
    }
}
