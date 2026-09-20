import Foundation

extension Identifier where Tag == FocusPresetTag {
    static let defaultPreset: FocusPresetID = "default"
    static let study: FocusPresetID = "study"
    static let deepWork: FocusPresetID = "deepWork"
    static let quickFocus: FocusPresetID = "quickFocus"
}

enum TaskBehavior: String, Codable, Hashable {
    /// Use the task selected on the Focus screen, if any.
    case useSelectedTask
    /// Start without a task.
    case noTask
}

/// What a preset *intends* to block. V1 records the intent only; the
/// `FocusBlockingService` in V1 is a clearly labeled mock that shields nothing.
enum BlockerIntent: String, Codable, Hashable, CaseIterable {
    case none
    case soft
    case strict

    var displayName: String {
        switch self {
        case .none: return "Off"
        case .soft: return "Chosen apps"
        case .strict: return "Apps + sites"
        }
    }
}

/// A reusable starting point for a session: timer, environment, sound, task
/// behavior, and blocker intent. NFC tags and deep links start presets by ID.
struct FocusPreset: Codable, Identifiable, Hashable {
    var id: FocusPresetID
    var name: String
    var timer: TimerConfiguration
    var sceneID: SceneID
    var renderMode: RenderMode
    var ambientMix: AmbientMix
    var taskBehavior: TaskBehavior
    var blockerIntent: BlockerIntent
    var isBuiltIn: Bool

    static let maximumNameLength = 24

    /// Trims and caps a preset name. Nil when nothing meaningful remains.
    static func normalizedName(_ raw: String) -> String? {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maximumNameLength))
    }

    /// A short, link-safe identifier for a preset the user made.
    static func makeCustomID() -> FocusPresetID {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
        return FocusPresetID("custom-\(suffix)")
    }

    /// The URL an NFC tag or Shortcut should open to start this preset.
    var startURL: URL {
        DeepLink.startFocus(presetID: id).url
    }
}
