import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

// This file is compiled into the app AND the optional StillLiveActivity widget
// extension, so it depends on Foundation (and ActivityKit) only.

/// Everything a Lock Screen / Dynamic Island presentation needs. No task
/// titles or other private text: the Lock Screen is visible to anyone nearby.
struct LiveActivityState: Codable, Hashable {
    var isBreak: Bool
    var isPaused: Bool
    var isAwaitingNextPhase: Bool
    /// Live countdown target. Nil when paused, waiting, or counting up.
    var phaseEndDate: Date?
    /// Start of an open-ended count-up, for a live elapsed timer.
    var countUpStartDate: Date?
    /// Frozen value shown while paused or waiting.
    var frozenSeconds: TimeInterval?
    var focusBlockNumber: Int
    var focusBlockCount: Int
    var sceneName: String
    var headline: String
}

#if canImport(ActivityKit) && os(iOS)
struct StillActivityAttributes: ActivityAttributes {
    typealias ContentState = LiveActivityState
    var sessionID: UUID
}
#endif
