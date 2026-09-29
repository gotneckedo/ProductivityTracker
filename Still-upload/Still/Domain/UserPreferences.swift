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

/// A visual choice for Still's ambient room companion. It never affects
/// progress, unlocks, or the cat's behavior.
enum CatCoat: String, Codable, CaseIterable, Hashable {
    case ginger
    case tabby
    case cream
    case midnight

    var title: String { rawValue.capitalized }

    var spriteAssetName: String {
        switch self {
        case .ginger: return "StillCatGingerSpriteSheet"
        case .tabby: return "StillCatTabbySpriteSheet"
        case .cream: return "StillCatCreamSpriteSheet"
        case .midnight: return "StillCatMidnightSpriteSheet"
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

/// A small Today template, intentionally separate from habits. Reordering or
/// removing it changes only the prompt shown on Today; it carries no streak,
/// score, or historical compliance data.
struct TodayRoutineItem: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String

    static let maximumTitleLength = 48

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = Self.normalized(title) ?? ""
    }

    static func normalized(_ raw: String) -> String? {
        let text = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !text.isEmpty else { return nil }
        return String(text.prefix(maximumTitleLength))
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
    /// Future Wake up hand-off. The notification fallback still uses the same
    /// Morning Start schedule.
    var wakeUpStopMethod: WakeUpStopMethod = .button
    /// Whether the day timeline may show Apple Calendar events.
    var showsCalendarEvents: Bool = false
    /// DEBUG/CI-demo sample Google events only. No account or token is stored.
    var showsGoogleCalendarEvents: Bool = false
    /// Named local sound mixes; the active mix remains on the current preset.
    var savedSoundscapes: [SavedSoundscape] = []
    /// Cosmetic room-company preference. Missing legacy values use Ginger.
    var catCoat: CatCoat = .ginger
    /// Optional, device-local companion name. It appears only in Cat settings
    /// and in a rare completed-session acknowledgement.
    var catName: String? = nil
    /// Local-only timestamp used solely to choose a different ambient cat pose
    /// after a long absence. It is not a check-in, reminder, score, or streak.
    var lastCatPresenceAt: Date?
    /// Tactile responses are local and can be turned off independently of
    /// motion. They default on because they are a direct control affordance.
    var hapticsEnabled: Bool = true
    /// Tiny interface sounds default off. Ambient sound remains controlled by
    /// the selected Focus mix, not by this accessibility preference.
    var interactionSoundsEnabled: Bool = false
    /// A local display order for room cards. Missing identifiers are appended
    /// from the shipped catalog, so future rooms cannot strand an old install.
    var sceneOrder: [SceneID] = []
    /// A local Break-shelf order. An empty value preserves the calm adaptive
    /// suggestion ranking until the person explicitly arranges the shelf.
    var breakActivityOrder: [BreakActivityID] = []
    /// Hidden activities remain installed and recoverable from shelf edit mode.
    var hiddenBreakActivityIDs: [BreakActivityID] = []
    /// Today prompts are editable templates, not a compliance tracker.
    var todayRoutineItems: [TodayRoutineItem] = []
    var schemaVersion: Int = UserPreferences.currentSchemaVersion

    static let currentSchemaVersion = 8

    init() {}

    private enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, onboardingGoal, breakAppeal, appAccentPalette, defaultPresetID, selectedTaskID
        case animationIntensity, hasRequestedNotificationPermission, notificationPermissionGranted
        case pendingCompletionSessionID, acknowledgedUnlockedSceneCount, morningStart, wakeUpStopMethod
        case showsCalendarEvents, showsGoogleCalendarEvents, savedSoundscapes, catCoat, catName, lastCatPresenceAt
        case hapticsEnabled, interactionSoundsEnabled, schemaVersion
        case sceneOrder, breakActivityOrder, hiddenBreakActivityIDs, todayRoutineItems
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
        wakeUpStopMethod = (try? c.decodeIfPresent(WakeUpStopMethod.self, forKey: .wakeUpStopMethod)) ?? .button
        showsCalendarEvents = (try? c.decodeIfPresent(Bool.self, forKey: .showsCalendarEvents)) ?? false
        showsGoogleCalendarEvents = (try? c.decodeIfPresent(Bool.self, forKey: .showsGoogleCalendarEvents)) ?? false
        savedSoundscapes = (try? c.decodeIfPresent([SavedSoundscape].self, forKey: .savedSoundscapes)) ?? []
        catCoat = (try? c.decodeIfPresent(CatCoat.self, forKey: .catCoat)) ?? .ginger
        catName = CatName.normalized(try? c.decodeIfPresent(String.self, forKey: .catName))
        lastCatPresenceAt = try c.decodeIfPresent(Date.self, forKey: .lastCatPresenceAt)
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        interactionSoundsEnabled = try c.decodeIfPresent(Bool.self, forKey: .interactionSoundsEnabled) ?? defaults.interactionSoundsEnabled
        sceneOrder = try c.decodeIfPresent([SceneID].self, forKey: .sceneOrder) ?? defaults.sceneOrder
        breakActivityOrder = try c.decodeIfPresent([BreakActivityID].self, forKey: .breakActivityOrder) ?? defaults.breakActivityOrder
        hiddenBreakActivityIDs = try c.decodeIfPresent([BreakActivityID].self, forKey: .hiddenBreakActivityIDs) ?? defaults.hiddenBreakActivityIDs
        todayRoutineItems = try c.decodeIfPresent([TodayRoutineItem].self, forKey: .todayRoutineItems) ?? defaults.todayRoutineItems
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
        if result.schemaVersion < 3 {
            result.savedSoundscapes = savedSoundscapes.map {
                SavedSoundscape(id: $0.id, name: $0.name, mix: $0.mix.normalized())
            }
        }
        if result.schemaVersion < 4 {
            result.catCoat = .ginger
        }
        if result.schemaVersion < 5 {
            result.catName = CatName.normalized(result.catName)
        }
        if result.schemaVersion < 6 {
            result.hapticsEnabled = true
            result.interactionSoundsEnabled = false
        }
        if result.schemaVersion < 7 {
            result.sceneOrder = []
            result.breakActivityOrder = []
            result.hiddenBreakActivityIDs = []
            result.todayRoutineItems = []
        }
        if result.schemaVersion < 8 {
            result.lastCatPresenceAt = nil
        }
        result.sceneOrder = Self.unique(result.sceneOrder)
        result.breakActivityOrder = Self.unique(result.breakActivityOrder)
        result.hiddenBreakActivityIDs = Self.unique(result.hiddenBreakActivityIDs)
        result.todayRoutineItems = Self.uniqueRoutineItems(result.todayRoutineItems.filter { !$0.title.isEmpty })
        result.catName = CatName.normalized(result.catName)
        result.schemaVersion = Self.currentSchemaVersion
        return result
    }

    private static func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func uniqueRoutineItems(_ values: [TodayRoutineItem]) -> [TodayRoutineItem] {
        var seen = Set<UUID>()
        return values.filter { seen.insert($0.id).inserted }
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
