#if DEBUG
import Foundation

/// Debug-only: opens the app on a specific screen with sample data, so CI can
/// take simulator screenshots. Never compiled into Release builds.
///
///   xcrun simctl launch booted com.cocomedia.still -still-demo home
///
/// Screens: onboarding, home, calm, active, complete, break, sudoku, wordsearch,
/// picross, picross-320, breathing, read, me, scenes, scenes-all, scenes-seasonal, card,
/// journal, presets, tasks, timeline, doodle, gallery, morning,
/// calendar-settings, get-card.
enum DemoLaunch {
    static let argument = "-still-demo"
    static let scrollBottomArgument = "-still-scroll-bottom"
    static let scrollMidpointArgument = "-still-scroll-midpoint"

    static var requestedScreen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// Used only by screenshot CI to prove the floating tab bar does not cover
    /// the final row of a tab. It has no production effect.
    static func shouldScrollToBottom(_ screen: String) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: scrollBottomArgument), index + 1 < arguments.count else { return false }
        return arguments[index + 1] == screen
    }

    /// Used only by screenshot CI to prove the short status-bar material fade
    /// on content which has genuinely moved beneath the top edge.
    static func shouldScrollToMidpoint(_ screen: String) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: scrollMidpointArgument), index + 1 < arguments.count else { return false }
        return arguments[index + 1] == screen
    }

    static func appState() -> AppState? {
        guard let screen = requestedScreen else { return nil }
        switch screen {
        case "onboarding":
            return PreviewSupport.appState(onboarded: false)
        case "home":
            return PreviewSupport.appState(populated: true)
        case "calm":
            return PreviewSupport.appState(goal: .calmerPhone, renderMode: .calm)
        case "active":
            return PreviewSupport.appState(populated: true, activeSession: true)
        case "complete":
            // bootstrap() reopens the pending completion screen.
            return PreviewSupport.completedSession().state
        case "break":
            return routed(.breakShelf)
        case "sudoku":
            return routed(.breakActivity(.sudoku, .shelf))
        case "wordsearch":
            return routed(.breakActivity(.wordSearch, .shelf))
        case "picross":
            return routed(.breakActivity(.picross, .shelf))
        case "picross-320":
            return routed(.breakActivity(.picross, .shelf))
        case "breathing":
            return routed(.breakActivity(.boxBreathing, .shelf))
        case "read":
            return routed(.breakActivity(.shortRead, .shelf))
        case "me":
            return routed(.me)
        case "scenes":
            return routed(.sceneCollection)
        case "scenes-all":
            let state = PreviewSupport.appState(populated: true, completedSessions: 30)
            state.router.go(to: .sceneCollection)
            return state
        case "scenes-seasonal":
            let state = PreviewSupport.appState(populated: true, completedSessions: 30)
            state.router.go(to: .sceneCollection)
            return state
        case "card":
            return routed(.nfcSetup)
        case "journal":
            return routed(.journal)
        case "presets":
            return routed(.presets)
        case "tasks":
            return routed(.tasks)
        case "timeline":
            return routed(.dayTimeline)
        case "doodle":
            return routed(.breakActivity(.pixelDoodle, .shelf))
        case "gallery":
            return routed(.doodleGallery)
        case "morning":
            return routed(.morningStart)
        case "calendar-settings":
            return routed(.calendarSettings)
        case "get-card":
            return routed(.getFocusCard)
        default:
            return nil
        }
    }

    private static func routed(_ route: AppRoute) -> AppState {
        let state = PreviewSupport.appState(populated: true)
        state.router.go(to: route)
        return state
    }
}
#endif
