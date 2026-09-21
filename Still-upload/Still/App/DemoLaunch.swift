#if DEBUG
import Foundation

/// Debug-only: opens the app on a specific screen with sample data, so CI can
/// take simulator screenshots. Never compiled into Release builds.
///
///   xcrun simctl launch booted com.cocomedia.still -still-demo home
///
/// Screens: onboarding, home, calm, active, complete, break, sudoku, wordsearch,
/// picross, breathing, read, me, scenes, card, journal, presets, tasks,
/// timeline, doodle, gallery, morning, calendar-settings, get-card.
enum DemoLaunch {
    static let argument = "-still-demo"

    static var requestedScreen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
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
        case "breathing":
            return routed(.breakActivity(.boxBreathing, .shelf))
        case "read":
            return routed(.breakActivity(.shortRead, .shelf))
        case "me":
            return routed(.me)
        case "scenes":
            return routed(.sceneCollection)
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
