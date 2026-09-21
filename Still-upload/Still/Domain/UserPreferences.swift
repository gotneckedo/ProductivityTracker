import Foundation

/// The one onboarding question: "What would you like help with?"
enum OnboardingGoal: String, Codable, CaseIterable, Hashable {
    case focusBetter
    case scrollLess
    case buildRoutine
    case calmerPhone

    var title: String {
        switch self {
        case .focusBetter: return "Focus better"
        case .scrollLess: return "Scroll less"
        case .buildRoutine: return "Build a routine"
        case .calmerPhone: return "Have a calmer phone"
        }
    }

    var detail: String {
        switch self {
        case .focusBetter: return "One task, one timer, then a real break."
        case .scrollLess: return "Something finite to reach for instead."
        case .buildRoutine: return "Small sessions that add up across days."
        case .calmerPhone: return "Quieter screens and gentler sound."
        }
    }
}

/// Device-local settings. Decoding tolerates missing keys so new fields can be
/// added in later versions without a migration.
struct UserPreferences: Codable, Equatable {
    var hasCompletedOnboarding: Bool = false
    var onboardingGoal: OnboardingGoal?
    /// The preset the Focus screen loads and the default NFC link starts.
    var defaultPresetID: FocusPresetID = .defaultPreset
    var selectedTaskID: UUID?
    var animationIntensity: AnimationIntensity = .full
    var hasRequestedNotificationPermission: Bool = false
    var notificationPermissionGranted: Bool?
    /// A completed session whose "What instead?" screen has not been dismissed.
    /// Survives relaunch so the completion moment is never skipped.
    var pendingCompletionSessionID: UUID?
    /// Number of scenes the user has already been shown as unlocked.
    var acknowledgedUnlockedSceneCount: Int = 1
    var morningStart: MorningStartPlan = .standard
    /// Future Wake up hand-off. The notification fallback still uses the same
    /// Morning Start schedule.
    var wakeUpStopMethod: WakeUpStopMethod = .button
    /// Whether the day timeline may show Apple Calendar events.
    var showsCalendarEvents: Bool = false
    /// DEBUG/CI-demo sample Google events only. No account or token is stored.
    var showsGoogleCalendarEvents: Bool = false
    var schemaVersion: Int = UserPreferences.currentSchemaVersion

    static let currentSchemaVersion = 1

    init() {}

    private enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, onboardingGoal, defaultPresetID, selectedTaskID
        case animationIntensity, hasRequestedNotificationPermission, notificationPermissionGranted
        case pendingCompletionSessionID, acknowledgedUnlockedSceneCount, morningStart, wakeUpStopMethod
        case showsCalendarEvents, showsGoogleCalendarEvents, schemaVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UserPreferences()
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaults.hasCompletedOnboarding
        onboardingGoal = try? c.decodeIfPresent(OnboardingGoal.self, forKey: .onboardingGoal)
        defaultPresetID = try c.decodeIfPresent(FocusPresetID.self, forKey: .defaultPresetID) ?? defaults.defaultPresetID
        selectedTaskID = try c.decodeIfPresent(UUID.self, forKey: .selectedTaskID)
        animationIntensity = (try? c.decodeIfPresent(AnimationIntensity.self, forKey: .animationIntensity)) ?? defaults.animationIntensity
        hasRequestedNotificationPermission = try c.decodeIfPresent(Bool.self, forKey: .hasRequestedNotificationPermission) ?? false
        notificationPermissionGranted = try c.decodeIfPresent(Bool.self, forKey: .notificationPermissionGranted)
        pendingCompletionSessionID = try c.decodeIfPresent(UUID.self, forKey: .pendingCompletionSessionID)
        acknowledgedUnlockedSceneCount = try c.decodeIfPresent(Int.self, forKey: .acknowledgedUnlockedSceneCount) ?? 1
        morningStart = (try? c.decodeIfPresent(MorningStartPlan.self, forKey: .morningStart)) ?? .standard
        wakeUpStopMethod = (try? c.decodeIfPresent(WakeUpStopMethod.self, forKey: .wakeUpStopMethod)) ?? .button
        showsCalendarEvents = (try? c.decodeIfPresent(Bool.self, forKey: .showsCalendarEvents)) ?? false
        showsGoogleCalendarEvents = (try? c.decodeIfPresent(Bool.self, forKey: .showsGoogleCalendarEvents)) ?? false
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? UserPreferences.currentSchemaVersion
    }
}

/// Copy and defaults derived from the onboarding answer. It softens emphasis;
/// it never locks the user into a mode.
struct Personalization {
    let goal: OnboardingGoal?

    var homeGreeting: String {
        switch goal {
        case .focusBetter: return "One thing at a time."
        case .scrollLess: return "Something better than scrolling."
        case .buildRoutine: return "Same time, small steps."
        case .calmerPhone: return "A quieter phone starts here."
        case nil: return "Ready when you are."
        }
    }

    var completionPrompt: String {
        "What do you want to do instead?"
    }

    /// Calm mode first for people who asked for a calmer phone.
    var preferredRenderMode: RenderMode {
        goal == .calmerPhone ? .calm : .scene
    }

    /// Ambient sound starts off for calmer-phone users; they can turn it on.
    var startsWithSound: Bool {
        goal != .calmerPhone
    }

    /// Show the task row prominently even when no task is selected.
    var emphasizesTasks: Bool {
        goal == .focusBetter || goal == .buildRoutine
    }

    /// Category order used to diversify break suggestions.
    var categoryOrder: [ActivityCategory] {
        switch goal {
        case .scrollLess: return [.puzzle, .quiet, .reset]
        case .calmerPhone: return [.reset, .quiet, .puzzle]
        case .buildRoutine: return [.quiet, .reset, .puzzle]
        case .focusBetter, nil: return [.reset, .puzzle, .quiet]
        }
    }
}
