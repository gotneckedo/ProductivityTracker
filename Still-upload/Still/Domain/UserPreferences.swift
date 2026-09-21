import Foundation

/// The first onboarding question: "What would you like help with?"
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

/// The kind of finite break a person would most like to see first. "Move"
/// maps to Reset because that category contains the guided physical routines.
enum BreakAppeal: String, Codable, CaseIterable, Hashable {
    case puzzles
    case quiet
    case move

    var title: String {
        switch self {
        case .puzzles: return "Puzzles"
        case .quiet: return "Something quiet"
        case .move: return "Move a little"
        }
    }

    var detail: String {
        switch self {
        case .puzzles: return "A small game with a clear ending."
        case .quiet: return "Read, draw, or write for a few minutes."
        case .move: return "Stretch, breathe, or step away."
        }
    }

    var category: ActivityCategory {
        switch self {
        case .puzzles: return .puzzle
        case .quiet: return .quiet
        case .move: return .reset
        }
    }
}

/// A restrained app accent paired with a matching Home Screen icon. The raw
/// icon names are an explicit contract with the app-icon asset catalogs.
enum AppAccentPalette: String, Codable, CaseIterable, Hashable {
    case mint
    case peach
    case sky

    var title: String {
        switch self {
        case .mint: return "Mint"
        case .peach: return "Peach"
        case .sky: return "Sky"
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .mint: return 0x3E8F74
        case .peach: return 0xC96F5D
        case .sky: return 0x5E86B3
        }
    }

    /// Nil restores the primary app icon.
    var alternateIconName: String? {
        switch self {
        case .mint: return nil
        case .peach: return "AppIconPeach"
        case .sky: return "AppIconSky"
        }
    }
}

struct OnboardingAnswers: Equatable {
    var goal: OnboardingGoal?
    var breakAppeal: BreakAppeal?
    var appAccentPalette: AppAccentPalette

    init(
        goal: OnboardingGoal? = nil,
        breakAppeal: BreakAppeal? = nil,
        appAccentPalette: AppAccentPalette = .mint
    ) {
        self.goal = goal
        self.breakAppeal = breakAppeal
        self.appAccentPalette = appAccentPalette
    }
}

/// Device-local settings. Decoding tolerates missing keys and `migrated()`
/// upgrades old payloads before they are returned by the repository.
struct UserPreferences: Codable, Equatable {
    var hasCompletedOnboarding: Bool = false
    var onboardingGoal: OnboardingGoal?
    var breakAppeal: BreakAppeal?
    var appAccentPalette: AppAccentPalette = .mint
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
    /// Whether the day timeline may show Apple Calendar events.
    var showsCalendarEvents: Bool = false
    var schemaVersion: Int = UserPreferences.currentSchemaVersion

    static let currentSchemaVersion = 2

    init() {}

    private enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, onboardingGoal, breakAppeal, appAccentPalette, defaultPresetID, selectedTaskID
        case animationIntensity, hasRequestedNotificationPermission, notificationPermissionGranted
        case pendingCompletionSessionID, acknowledgedUnlockedSceneCount, morningStart, showsCalendarEvents, schemaVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UserPreferences()
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaults.hasCompletedOnboarding
        onboardingGoal = try? c.decodeIfPresent(OnboardingGoal.self, forKey: .onboardingGoal)
        breakAppeal = try? c.decodeIfPresent(BreakAppeal.self, forKey: .breakAppeal)
        appAccentPalette = (try? c.decodeIfPresent(AppAccentPalette.self, forKey: .appAccentPalette)) ?? defaults.appAccentPalette
        defaultPresetID = try c.decodeIfPresent(FocusPresetID.self, forKey: .defaultPresetID) ?? defaults.defaultPresetID
        selectedTaskID = try c.decodeIfPresent(UUID.self, forKey: .selectedTaskID)
        animationIntensity = (try? c.decodeIfPresent(AnimationIntensity.self, forKey: .animationIntensity)) ?? defaults.animationIntensity
        hasRequestedNotificationPermission = try c.decodeIfPresent(Bool.self, forKey: .hasRequestedNotificationPermission) ?? false
        notificationPermissionGranted = try c.decodeIfPresent(Bool.self, forKey: .notificationPermissionGranted)
        pendingCompletionSessionID = try c.decodeIfPresent(UUID.self, forKey: .pendingCompletionSessionID)
        acknowledgedUnlockedSceneCount = try c.decodeIfPresent(Int.self, forKey: .acknowledgedUnlockedSceneCount) ?? 1
        morningStart = (try? c.decodeIfPresent(MorningStartPlan.self, forKey: .morningStart)) ?? .standard
        showsCalendarEvents = (try? c.decodeIfPresent(Bool.self, forKey: .showsCalendarEvents)) ?? false
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self = migrated()
    }

    func migrated() -> UserPreferences {
        var result = self
        // Version 2 added optional break appeal and a non-optional visual
        // default. Tolerant decoding supplied both values; advancing the
        // version makes the migration explicit and idempotent.
        if result.schemaVersion < 2 {
            result.appAccentPalette = appAccentPalette
        }
        result.schemaVersion = Self.currentSchemaVersion
        return result
    }
}

/// Copy and defaults derived from the onboarding answer. It softens emphasis;
/// it never locks the user into a mode.
struct Personalization {
    let goal: OnboardingGoal?
    let breakAppeal: BreakAppeal?

    init(goal: OnboardingGoal?, breakAppeal: BreakAppeal? = nil) {
        self.goal = goal
        self.breakAppeal = breakAppeal
    }

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
        let goalOrder: [ActivityCategory]
        switch goal {
        case .scrollLess: goalOrder = [.puzzle, .quiet, .reset]
        case .calmerPhone: goalOrder = [.reset, .quiet, .puzzle]
        case .buildRoutine: goalOrder = [.quiet, .reset, .puzzle]
        case .focusBetter, nil: goalOrder = [.reset, .puzzle, .quiet]
        }
        guard let preferred = breakAppeal?.category else { return goalOrder }
        return [preferred] + goalOrder.filter { $0 != preferred }
    }
}
