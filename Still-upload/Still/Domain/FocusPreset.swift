import Foundation

extension Identifier where Tag == FocusPresetTag {
    static let defaultPreset: FocusPresetID = "default"
    static let study: FocusPresetID = "study"
}

enum TaskBehavior: String, Codable, Hashable {
    /// Use the task selected on the Focus screen, if any.
    case useSelectedTask
    /// Start without a task.
    case noTask
}

/// What a preset *intends* to block. V1 records the intent only; the
/// `FocusBlockingService` in V1 is a clearly labeled mock that shields nothing.
enum BlockerIntent: String, Codable, Hashable {
    case none
    case soft
    case strict
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

    /// The URL an NFC tag or Shortcut should open to start this preset.
    var startURL: URL {
        DeepLink.startFocus(presetID: id).url
    }
}
