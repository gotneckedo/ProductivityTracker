import Foundation

/// The complete local event vocabulary. Stable snake_case names so a future
/// privacy-respecting destination can map them 1:1.
enum AppEventName: String, CaseIterable, Hashable {
    case onboardingCompleted = "onboarding_completed"
    case focusStarted = "focus_started"
    case focusPaused = "focus_paused"
    case focusResumed = "focus_resumed"
    case focusCompleted = "focus_completed"
    case focusAbandoned = "focus_abandoned"
    case breakSuggestionsPresented = "break_suggestions_presented"
    case breakActivityStarted = "break_activity_started"
    case breakActivityCompleted = "break_activity_completed"
    case breakActivityAbandoned = "break_activity_abandoned"
    case returnedToFocus = "returned_to_focus"
    case nfcPresetRouted = "nfc_preset_routed"
    case notificationPermissionResult = "notification_permission_result"
}

enum EventPropertyKey: String, CaseIterable, Hashable {
    case timerMode = "timer_mode"
    case presetID = "preset_id"
    case activityID = "activity_id"
    case durationBucket = "duration_bucket"
    case userInitiated = "user_initiated"
    case granted
    case source
    case goal
    case suggestionRank = "suggestion_rank"
    case count
    case entryPoint = "entry_point"
}

/// A short, machine-shaped token. Anything that does not look like an
/// identifier is replaced with `redacted`, so free text cannot leak even if a
/// future caller passes the wrong value.
struct SafeToken: Hashable, CustomStringConvertible {
    static let redacted = "redacted"
    static let maximumLength = 32

    let value: String

    fileprivate init(_ raw: String) {
        value = SafeToken.isSafe(raw) ? raw : SafeToken.redacted
    }

    /// Letters, digits, and underscores only; no spaces; bounded length.
    static func isSafe(_ raw: String) -> Bool {
        guard !raw.isEmpty, raw.count <= maximumLength else { return false }
        return raw.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 48 && scalar.value <= 57)      // 0-9
                || (scalar.value >= 65 && scalar.value <= 90)  // A-Z
                || (scalar.value >= 97 && scalar.value <= 122) // a-z
                || scalar == "_"
        }
    }

    var description: String { value }
}

enum EventPropertyValue: Hashable, CustomStringConvertible {
    case bool(Bool)
    case int(Int)
    case token(SafeToken)

    var description: String {
        switch self {
        case .bool(let value): return value ? "true" : "false"
        case .int(let value): return String(value)
        case .token(let token): return token.value
        }
    }
}

/// Builds event properties from typed values only. There is intentionally no
/// method that accepts an arbitrary `String`: task titles, notes, Brain Dump
/// text, and journal text have no path into analytics.
struct EventProperties: Hashable {
    private(set) var values: [EventPropertyKey: EventPropertyValue] = [:]

    init() {}

    func timerMode(_ mode: TimerMode) -> EventProperties {
        setting(.timerMode, .token(SafeToken(mode.rawValue)))
    }

    /// Built-in presets are reported by ID; any user-made preset becomes `custom`.
    func preset(_ id: FocusPresetID) -> EventProperties {
        let known: Set<FocusPresetID> = [.defaultPreset, .study]
        return setting(.presetID, .token(SafeToken(known.contains(id) ? id.rawValue : "custom")))
    }

    /// Catalog activities are reported by ID; anything else becomes `custom`.
    func activity(_ id: BreakActivityID) -> EventProperties {
        let known = Set(ActivityCatalog.all.map(\.id))
        return setting(.activityID, .token(SafeToken(known.contains(id) ? id.rawValue : "custom")))
    }

    func duration(_ seconds: TimeInterval) -> EventProperties {
        setting(.durationBucket, .token(SafeToken(EventProperties.bucket(for: seconds))))
    }

    func userInitiated(_ value: Bool) -> EventProperties {
        setting(.userInitiated, .bool(value))
    }

    func granted(_ value: Bool) -> EventProperties {
        setting(.granted, .bool(value))
    }

    func source(_ source: SessionSource) -> EventProperties {
        setting(.source, .token(SafeToken(source.rawValue)))
    }

    func goal(_ goal: OnboardingGoal) -> EventProperties {
        setting(.goal, .token(SafeToken(goal.rawValue)))
    }

    func entryPoint(_ entry: ActivityEntryPoint) -> EventProperties {
        setting(.entryPoint, .token(SafeToken(entry.rawValue)))
    }

    func suggestionRank(_ rank: Int) -> EventProperties {
        setting(.suggestionRank, .int(rank))
    }

    func count(_ value: Int) -> EventProperties {
        setting(.count, .int(value))
    }

    /// Coarse duration buckets: exact durations are not needed for the funnel.
    static func bucket(for seconds: TimeInterval) -> String {
        switch seconds {
        case ..<60: return "under_1m"
        case ..<(5 * 60): return "m1_5"
        case ..<(15 * 60): return "m5_15"
        case ..<(30 * 60): return "m15_30"
        case ..<(60 * 60): return "m30_60"
        default: return "over_60m"
        }
    }

    /// Exposed for tests: builds a token through the same sanitizer.
    static func sanitizedToken(_ raw: String) -> String {
        SafeToken(raw).value
    }

    private func setting(_ key: EventPropertyKey, _ value: EventPropertyValue) -> EventProperties {
        var copy = self
        copy.values[key] = value
        return copy
    }
}

struct AppEvent: Identifiable, Hashable {
    let id: UUID
    let name: AppEventName
    let timestamp: Date
    let properties: EventProperties
}
