import Foundation

enum SessionState: String, Codable, Hashable {
    case active
    case paused
    case completed
    /// Ended early by the user. Never counts toward stats, streaks, or unlocks.
    case abandoned

    var isLive: Bool { self == .active || self == .paused }
}

enum SessionSource: String, Codable, Hashable {
    case manual
    case deepLink
    case nfcSimulator
}

enum RenderMode: String, Codable, CaseIterable, Hashable {
    /// A mostly static pixel plant nook; the timer carries the screen.
    case calm
    /// An original animated pixel loop.
    case scene

    var displayName: String {
        switch self {
        case .calm: return "Calm"
        case .scene: return "Scene"
        }
    }
}

/// A focus session. All timing is derived from stored dates, never from a
/// decrementing counter, so the session survives backgrounding and relaunch.
///
/// Timing model:
/// - `phaseIndex` points into `configuration.phases`.
/// - While running, elapsed time in the current phase is
///   `phaseAccumulated + (now - phaseStartedAt)`.
/// - Pausing folds the running stretch into `phaseAccumulated`.
/// - When a phase ends and the next one is not set to auto-start, the session
///   waits (`isAwaitingNextPhase`) with the finished phase frozen at full length.
struct FocusSession: Codable, Identifiable, Hashable {
    var id: UUID
    var createdAt: Date
    var startedAt: Date
    var endedAt: Date?
    var state: SessionState
    var configuration: TimerConfiguration
    var taskID: UUID?
    var sceneID: SceneID
    var renderMode: RenderMode
    var presetID: FocusPresetID
    var source: SessionSource

    var phaseIndex: Int
    var phaseStartedAt: Date
    var phaseAccumulated: TimeInterval
    var pausedAt: Date?
    var isAwaitingNextPhase: Bool

    /// Sum of focus phases that ran to completion (or the whole count-up span once finished).
    var completedFocusDuration: TimeInterval
    var completedFocusPhases: Int
    var pauseCount: Int

    /// Reserved for V1.1+ session notes. Private; never sent to analytics.
    var note: String?
    var schemaVersion: Int

    static let currentSchemaVersion = 1

    var phases: [FocusPhase] { configuration.phases }

    var currentPhase: FocusPhase? {
        phases.indices.contains(phaseIndex) ? phases[phaseIndex] : nil
    }

    var nextPhase: FocusPhase? {
        phases.indices.contains(phaseIndex + 1) ? phases[phaseIndex + 1] : nil
    }

    /// Focus time that counts toward stats. Zero unless completed.
    var countedFocusDuration: TimeInterval {
        state == .completed ? completedFocusDuration : 0
    }
}
