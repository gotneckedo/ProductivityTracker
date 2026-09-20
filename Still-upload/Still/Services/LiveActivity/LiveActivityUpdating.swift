import Foundation

/// Maps timer state to Live Activity content. Pure and testable.
enum LiveActivityMapper {
    static func state(for snapshot: TimerSnapshot, sceneName: String, now: Date) -> LiveActivityState? {
        guard snapshot.state.isLive else { return nil }

        let headline: String
        if snapshot.isAwaitingNextPhase {
            headline = snapshot.nextPhaseKind == .focus ? "Break's over" : "Break ready"
        } else if snapshot.isPaused {
            headline = "Paused"
        } else {
            headline = snapshot.phaseKind.displayName
        }

        let isCountUp = snapshot.phaseDuration == nil
        let countUpStart: Date? = (isCountUp && snapshot.isRunning)
            ? now.addingTimeInterval(-snapshot.elapsedInPhase)
            : nil

        return LiveActivityState(
            isBreak: snapshot.phaseKind.isBreak,
            isPaused: snapshot.isPaused,
            isAwaitingNextPhase: snapshot.isAwaitingNextPhase,
            phaseEndDate: snapshot.phaseEndDate,
            countUpStartDate: countUpStart,
            frozenSeconds: snapshot.isRunning ? nil : snapshot.displayedSeconds,
            focusBlockNumber: snapshot.focusBlockNumber,
            focusBlockCount: snapshot.focusBlockCount,
            sceneName: sceneName,
            headline: headline
        )
    }
}

/// Boundary for Lock Screen and Dynamic Island updates. The app is fully
/// functional with `NoopLiveActivityUpdater`.
protocol LiveActivityUpdating: AnyObject {
    var isAvailable: Bool { get }
    func startOrUpdate(sessionID: UUID, state: LiveActivityState)
    func end(sessionID: UUID)
}

final class NoopLiveActivityUpdater: LiveActivityUpdating {
    let isAvailable = false
    private(set) var lastState: LiveActivityState?
    private(set) var endedSessionIDs: [UUID] = []

    func startOrUpdate(sessionID: UUID, state: LiveActivityState) {
        lastState = state
    }

    func end(sessionID: UUID) {
        lastState = nil
        endedSessionIDs.append(sessionID)
    }
}

// MARK: - ActivityKitLiveActivityUpdater

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// Real Live Activity updates. Only used when `FeatureFlags.liveActivities`
/// is on AND the StillLiveActivity widget extension is part of the build;
/// without the extension, iOS has nothing to render. See README.
final class ActivityKitLiveActivityUpdater: LiveActivityUpdating {
    private var activity: Activity<StillActivityAttributes>?

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func startOrUpdate(sessionID: UUID, state: LiveActivityState) {
        let content = ActivityContent(state: state, staleDate: state.phaseEndDate?.addingTimeInterval(60))
        if let current = activity, current.attributes.sessionID == sessionID {
            Task { await current.update(content) }
            return
        }
        endAll()
        guard isAvailable else { return }
        do {
            activity = try Activity.request(
                attributes: StillActivityAttributes(sessionID: sessionID),
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities are optional; the in-app timer is the source of truth.
            activity = nil
        }
    }

    func end(sessionID: UUID) {
        guard let current = activity, current.attributes.sessionID == sessionID else { return }
        activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }

    private func endAll() {
        let existing = Activity<StillActivityAttributes>.activities
        activity = nil
        for item in existing {
            Task { await item.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
#endif
