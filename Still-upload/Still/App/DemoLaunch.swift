#if DEBUG
import Foundation

/// Debug-only: opens the app on a specific screen with sample data, so CI can
/// take simulator screenshots. Never compiled into Release builds.
///
///   xcrun simctl launch booted com.cocomedia.still -still-demo home
///
/// Screens: onboarding, today, today-light, setup, home, focus-room, room-library, room-train, room-city,
/// room-autumn, room-snow, room-spring, room-sleep, room-collectibles, sprite-contact-sheet,
/// cat-morning, cat-reaction, cat-focus, cat-asleep, cat-complete, calm, active, complete, break, sudoku, wordsearch,
/// picross, picross-320, breathing, read, me, scenes, scenes-all, scenes-extra, card,
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
        case "today":
            return routed(.today)
        case "today-light":
            // `simctl status_bar` changes chrome only; the app's local clock
            // still controls its time-aware phase. Pin a morning fixture so CI
            // proves the intentionally light page and surface hierarchy.
            return todayState(hour: 9)
        case "setup":
            return routed(.focusConfiguration)
        case "home":
            return PreviewSupport.appState(populated: true)
        case "focus-room":
            // One completed session provides a selected task while the native
            // room targets remain invisible and VoiceOver-labeled, preserving
            // a clean art review surface.
            let state = PreviewSupport.appState(populated: true, completedSessions: 1)
            state.router.go(to: .focusHome)
            return state
        case "room-library":
            return focusRoomState(hour: 14, sceneID: .libraryLight)
        case "room-train":
            return focusRoomState(hour: 14, sceneID: .trainWindow)
        case "room-city":
            return focusRoomState(hour: 20, sceneID: .nightCity)
        case "room-autumn":
            return focusRoomState(hour: 14, sceneID: .autumnWindow, stillPlus: true)
        case "room-snow":
            return focusRoomState(hour: 10, sceneID: .snowDay, stillPlus: true)
        case "room-spring":
            return focusRoomState(hour: 14, sceneID: .springRain, stillPlus: true)
        case "room-sleep":
            // The sleep room is reserved for a later DEBUG-only alarm preview;
            // this direct review route verifies its bundled art without implying
            // an armable production alarm.
            return routed(.spriteContactSheet)
        case "room-collectibles":
            return roomWithPlacedCollectibles()
        case "cat-morning":
            return focusRoomState(hour: 9)
        case "cat-reaction":
            return focusRoomState(hour: 14)
        case "cat-focus":
            return activeCatState(elapsed: 4 * 60)
        case "cat-asleep":
            return activeCatState(elapsed: 12 * 60)
        case "cat-complete":
            let completed = PreviewSupport.completedSession()
            completed.state.setCatName("Mochi")
            return completed.state
        case "sprite-contact-sheet":
            return routed(.spriteContactSheet)
        case "calm":
            return PreviewSupport.appState(goal: .calmerPhone, renderMode: .calm)
        case "active":
            // The fixture advances seven minutes, so initialize it at 9:34 to
            // match CI's fixed 9:41 status-bar clock. An 18-minute remaining
            // face must therefore truthfully show 9:59 AM.
            return activeState()
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
        case "scenes-extra":
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

    private static func focusRoomState(
        hour: Int,
        sceneID: SceneID = .rainyBedroom,
        stillPlus: Bool = false
    ) -> AppState {
        let state = PreviewSupport.appState(
            populated: true,
            completedSessions: sceneID == .rainyBedroom ? 1 : 30,
            clockStart: screenshotDate(hour: hour, minute: 0),
            stillPlus: stillPlus
        )
        var preset = state.currentPreset
        preset.sceneID = sceneID
        state.savePreset(preset)
        state.setCatName("Mochi")
        state.router.go(to: .focusHome)
        return state
    }

    private static func todayState(hour: Int) -> AppState {
        let state = PreviewSupport.appState(
            populated: true,
            clockStart: screenshotDate(hour: hour, minute: 0)
        )
        state.router.go(to: .today)
        return state
    }

    private static func roomWithPlacedCollectibles() -> AppState {
        // Use only the early, naturally earned objects so this review fixture
        // proves actual sprite anchors without a fake entitlement or inventory.
        let state = PreviewSupport.appState(
            populated: true,
            completedSessions: 30,
            clockStart: screenshotDate(hour: 14, minute: 0)
        )
        var preset = state.currentPreset
        preset.sceneID = .rainyBedroom
        state.savePreset(preset)
        state.setCatName("Mochi")
        state.router.go(to: .focusHome)
        state.placeRoomObject(.pencilCup, in: .rainyBedroom, slot: .desk)
        state.placeRoomObject(.radio, in: .rainyBedroom, slot: .shelf)
        state.placeRoomObject(.wovenRug, in: .rainyBedroom, slot: .floorCorner)
        state.placeRoomObject(.trailingPlant, in: .rainyBedroom, slot: .windowsill)
        state.notice = nil
        return state
    }

    private static func activeCatState(elapsed: TimeInterval) -> AppState {
        let state = PreviewSupport.appState(
            populated: true,
            activeSession: true,
            activeSessionElapsed: elapsed,
            clockStart: screenshotDate(hour: 14, minute: 0)
        )
        state.setCatName("Mochi")
        // Starting a preview session does not implicitly choose the Focus tab.
        // The explicit root route keeps the visual proof on ActiveFocusView
        // rather than leaving Today visible while the tab bar is suppressed.
        if let id = state.activeSession?.id {
            state.router.go(to: .activeSession(id))
        }
        return state
    }

    private static func activeState() -> AppState {
        let state = PreviewSupport.appState(
            populated: true,
            activeSession: true,
            clockStart: screenshotActiveSessionStart
        )
        if let id = state.activeSession?.id {
            state.router.go(to: .activeSession(id))
        }
        return state
    }

    private static func screenshotDate(hour: Int, minute: Int) -> Date {
        var components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: .now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.autoupdatingCurrent.date(from: components) ?? .now
    }

    private static var screenshotActiveSessionStart: Date {
        screenshotDate(hour: 9, minute: 34)
    }
}
#endif
