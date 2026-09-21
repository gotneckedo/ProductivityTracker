import Foundation

/// Compile-time switches for capabilities that exist as boundaries but are not
/// shipped in V1. Turning a flag on must not require a navigation redesign.
struct FeatureFlags: Equatable {
    /// V1.1 one-line journal tab.
    var journalTab: Bool
    /// Requires the StillLiveActivity widget extension to be added to the project.
    var liveActivities: Bool
    /// V1.1 calm-mode plant growth.
    var plantGrowthStages: Bool
    /// V2 Family Controls shielding. Requires Apple entitlement approval.
    var appBlocking: Bool
    /// V3 speech-to-task capture (needs microphone and speech permission).
    var voiceCapture: Bool = false
    /// V3 read-only Apple Calendar events on the day timeline.
    var calendarEvents: Bool = false

    /// The original V1 surface. Kept so tests can pin V1 behavior.
    static let v1 = FeatureFlags(journalTab: false, liveActivities: false, plantGrowthStages: false, appBlocking: false)

    /// What ships today. App blocking stays off until Apple approves the
    /// Family Controls entitlement; see FUTURE_CAPABILITIES.md.
    static let current = FeatureFlags(
        journalTab: true,
        liveActivities: true,
        plantGrowthStages: true,
        appBlocking: false,
        voiceCapture: true,
        calendarEvents: true
    )
}

enum AppTab: String, CaseIterable, Hashable {
    case focus
    case breakShelf
    case journal
    case me

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .breakShelf: return "Break"
        case .journal: return "Journal"
        case .me: return "Me"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: return "circle.circle"
        case .breakShelf: return "cup.and.saucer"
        case .journal: return "book.closed"
        case .me: return "person.crop.circle"
        }
    }

    static func visibleTabs(flags: FeatureFlags) -> [AppTab] {
        flags.journalTab ? [.focus, .breakShelf, .journal, .me] : [.focus, .breakShelf, .me]
    }
}

/// Every destination in the app. Views never decide presentation; they ask the
/// router to go to a route, and `RouteResolver` decides tab, stack, and modal.
enum AppRoute: Hashable {
    case focusHome
    case focusConfiguration
    case activeSession(UUID)
    case sessionComplete(UUID)
    case breakShelf
    case breakActivity(BreakActivityID, ActivityContext)
    case tasks
    case me
    case nfcSetup
    case sceneCollection
    case roomCollection
    case journal
    case presets
    case doodleGallery
    case dayTimeline
    case morningStart
    case blockingSetup
    case habits
}

enum SheetRoute: String, Identifiable, Hashable {
    case focusConfiguration
    case tasks
    case dayTimeline

    var id: String { rawValue }
}

/// Resolved presentation for a route.
struct RouteDestination: Equatable {
    var tab: AppTab
    /// Screens pushed on that tab's navigation stack, in order.
    var stack: [AppRoute]
    var sheet: SheetRoute?
    /// A session whose completion screen should be presented full screen.
    var completionSessionID: UUID?
}

struct RouteResolver {
    var flags: FeatureFlags

    func destination(for route: AppRoute, currentTab: AppTab) -> RouteDestination {
        switch route {
        case .focusHome, .activeSession:
            // The Focus root itself switches between home and the active session.
            return RouteDestination(tab: .focus, stack: [], sheet: nil, completionSessionID: nil)
        case .focusConfiguration:
            // Sheets open over whatever tab is showing and leave its stack alone.
            return RouteDestination(tab: currentTab, stack: [], sheet: .focusConfiguration, completionSessionID: nil)
        case .sessionComplete(let id):
            return RouteDestination(tab: .focus, stack: [], sheet: nil, completionSessionID: id)
        case .breakShelf:
            return RouteDestination(tab: .breakShelf, stack: [], sheet: nil, completionSessionID: nil)
        case .breakActivity:
            return RouteDestination(tab: .breakShelf, stack: [route], sheet: nil, completionSessionID: nil)
        case .tasks:
            return RouteDestination(tab: currentTab, stack: [], sheet: .tasks, completionSessionID: nil)
        case .roomCollection:
            return RouteDestination(tab: .focus, stack: [route], sheet: nil, completionSessionID: nil)
        case .me:
            return RouteDestination(tab: .me, stack: [], sheet: nil, completionSessionID: nil)
        case .nfcSetup, .sceneCollection, .presets, .doodleGallery, .morningStart, .blockingSetup:
            return RouteDestination(tab: .me, stack: [route], sheet: nil, completionSessionID: nil)
        case .dayTimeline:
            return RouteDestination(tab: currentTab, stack: [], sheet: .dayTimeline, completionSessionID: nil)
        case .habits:
            // Habits live on the Journal tab; without it they sit under Me.
            return flags.journalTab
                ? RouteDestination(tab: .journal, stack: [], sheet: nil, completionSessionID: nil)
                : RouteDestination(tab: .me, stack: [route], sheet: nil, completionSessionID: nil)
        case .journal:
            // Hidden in V1: fall back to Me rather than show a placeholder.
            return flags.journalTab
                ? RouteDestination(tab: .journal, stack: [], sheet: nil, completionSessionID: nil)
                : RouteDestination(tab: .me, stack: [], sheet: nil, completionSessionID: nil)
        }
    }
}
