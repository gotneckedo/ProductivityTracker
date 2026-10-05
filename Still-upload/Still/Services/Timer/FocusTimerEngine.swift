import Foundation

/// A read-only view of a session at one instant. Everything the UI shows about
/// time comes from here.
struct TimerSnapshot: Equatable {
    var sessionID: UUID
    var mode: TimerMode
    var state: SessionState
    var phaseKind: FocusPhaseKind
    var phaseIndex: Int
    var phaseCount: Int
    /// 1-based number of the current (or just-finished) focus block.
    var focusBlockNumber: Int
    var focusBlockCount: Int
    var elapsedInPhase: TimeInterval
    /// Nil for open-ended (count-up) phases.
    var phaseDuration: TimeInterval?
    var remainingInPhase: TimeInterval?
    var isAwaitingNextPhase: Bool
    /// The phase that will start next, if any.
    var nextPhaseKind: FocusPhaseKind?
    /// Completed focus plus the running focus phase.
    var totalFocusElapsed: TimeInterval
    /// When the running fixed-length phase will end. Nil when paused, waiting, or open-ended.
    var phaseEndDate: Date?

    var isPaused: Bool { state == .paused }
    var isRunning: Bool { state == .active && !isAwaitingNextPhase }

    /// 0...1 through the current phase, or nil for count-up.
    var phaseProgress: Double? {
        guard let duration = phaseDuration, duration > 0 else { return nil }
        return min(1, max(0, elapsedInPhase / duration))
    }

    /// The number the timer face shows: remaining for fixed phases, elapsed for count-up.
    var displayedSeconds: TimeInterval {
        remainingInPhase ?? elapsedInPhase
    }

    /// Calculates the displayed end time from the instant the UI is rendered
    /// and the current remaining duration. This keeps the status line in step
    /// with a live countdown even if a previously stored phase timestamp was
    /// created before a pause, resume, or focus extension.
    func endDate(from now: Date) -> Date? {
        guard isRunning, let remainingInPhase else { return nil }
        return now.addingTimeInterval(max(0, remainingInPhase))
    }
}

enum TimerTransition: Equatable {
    case phaseCompleted(index: Int, kind: FocusPhaseKind, at: Date)
    case phaseStarted(index: Int, kind: FocusPhaseKind, at: Date)
    case awaitingNextPhase(nextIndex: Int, kind: FocusPhaseKind)
    case sessionCompleted(at: Date)
}

/// A future moment when a phase ends, used to schedule local notifications.
struct PhaseBoundary: Equatable {
    var date: Date
    var endingPhaseIndex: Int
    var endingKind: FocusPhaseKind
    /// The phase that follows, or nil when the session ends here.
    var nextKind: FocusPhaseKind?
    /// True when the next phase will not start by itself.
    var requiresUserToContinue: Bool

    var endsSession: Bool { nextKind == nil }
}

/// Pure, date-based timer rules. No stored counters, no side effects.
/// Every function takes the session and a date and returns a new session.
struct FocusTimerEngine {
    /// Upper bound on scheduled boundaries (notifications are limited per app).
    static let maximumBoundaries = 16

    func makeSession(
        id: UUID = UUID(),
        configuration: TimerConfiguration,
        taskID: UUID?,
        sceneID: SceneID,
        renderMode: RenderMode,
        presetID: FocusPresetID,
        source: SessionSource,
        at now: Date
    ) -> FocusSession {
        FocusSession(
            id: id,
            createdAt: now,
            startedAt: now,
            endedAt: nil,
            state: .active,
            configuration: configuration.validated(),
            taskID: taskID,
            sceneID: sceneID,
            renderMode: renderMode,
            presetID: presetID,
            source: source,
            phaseIndex: 0,
            phaseStartedAt: now,
            phaseAccumulated: 0,
            pausedAt: nil,
            isAwaitingNextPhase: false,
            completedFocusDuration: 0,
            completedFocusPhases: 0,
            pauseCount: 0,
            note: nil,
            schemaVersion: FocusSession.currentSchemaVersion
        )
    }

    // MARK: - Advancing

    /// Rolls the session forward to `now`, completing any phases whose end has
    /// passed. Safe to call repeatedly; handles long gaps (backgrounding,
    /// relaunch) by walking every boundary in order with exact end dates.
    func advance(_ session: FocusSession, to now: Date) -> (FocusSession, [TimerTransition]) {
        var s = session
        var transitions: [TimerTransition] = []
        guard s.state == .active, !s.isAwaitingNextPhase else { return (s, transitions) }

        let phases = s.phases
        while s.phaseIndex < phases.count {
            let phase = phases[s.phaseIndex]
            guard let duration = phase.duration else { break }
            let elapsed = s.phaseAccumulated + max(0, now.timeIntervalSince(s.phaseStartedAt))
            guard elapsed >= duration else { break }

            let phaseEnd = s.phaseStartedAt.addingTimeInterval(duration - s.phaseAccumulated)
            if phase.kind == .focus {
                s.completedFocusDuration += duration
                s.completedFocusPhases += 1
            }
            transitions.append(.phaseCompleted(index: s.phaseIndex, kind: phase.kind, at: phaseEnd))

            let nextIndex = s.phaseIndex + 1
            guard nextIndex < phases.count else {
                s.state = .completed
                s.endedAt = phaseEnd
                s.phaseAccumulated = duration
                s.phaseStartedAt = phaseEnd
                transitions.append(.sessionCompleted(at: phaseEnd))
                break
            }

            let nextKind = phases[nextIndex].kind
            if autoStarts(nextKind, in: s.configuration) {
                s.phaseIndex = nextIndex
                s.phaseStartedAt = phaseEnd
                s.phaseAccumulated = 0
                transitions.append(.phaseStarted(index: nextIndex, kind: nextKind, at: phaseEnd))
            } else {
                s.isAwaitingNextPhase = true
                s.phaseAccumulated = duration
                s.phaseStartedAt = phaseEnd
                transitions.append(.awaitingNextPhase(nextIndex: nextIndex, kind: nextKind))
                break
            }
        }
        return (s, transitions)
    }

    // MARK: - Snapshot

    func snapshot(of session: FocusSession, at now: Date) -> TimerSnapshot {
        let (s, _) = advance(session, to: now)
        let phases = s.phases
        let index = min(s.phaseIndex, max(0, phases.count - 1))
        let phase = phases.isEmpty ? FocusPhase(kind: .focus, duration: nil) : phases[index]
        let elapsed = elapsedInPhase(s, at: now)
        let remaining = phase.duration.map { max(0, $0 - elapsed) }
        let focusNumber = phases.prefix(index + 1).filter { $0.kind == .focus }.count
        let nextKind = phases.indices.contains(index + 1) ? phases[index + 1].kind : nil

        var totalFocus = s.completedFocusDuration
        if s.state.isLive, !s.isAwaitingNextPhase, phase.kind == .focus {
            totalFocus += elapsed
        }

        var endDate: Date?
        if s.state == .active, !s.isAwaitingNextPhase, let duration = phase.duration {
            endDate = s.phaseStartedAt.addingTimeInterval(duration - s.phaseAccumulated)
        }

        return TimerSnapshot(
            sessionID: s.id,
            mode: s.configuration.mode,
            state: s.state,
            phaseKind: phase.kind,
            phaseIndex: index,
            phaseCount: phases.count,
            focusBlockNumber: max(1, focusNumber),
            focusBlockCount: s.configuration.focusBlockCount,
            elapsedInPhase: elapsed,
            phaseDuration: phase.duration,
            remainingInPhase: remaining,
            isAwaitingNextPhase: s.isAwaitingNextPhase,
            nextPhaseKind: nextKind,
            totalFocusElapsed: totalFocus,
            phaseEndDate: endDate
        )
    }

    // MARK: - User actions

    func pause(_ session: FocusSession, at now: Date) -> (FocusSession, [TimerTransition]) {
        var (s, transitions) = advance(session, to: now)
        guard s.state == .active, !s.isAwaitingNextPhase else { return (s, transitions) }
        s.phaseAccumulated += max(0, now.timeIntervalSince(s.phaseStartedAt))
        s.phaseStartedAt = now
        s.pausedAt = now
        s.state = .paused
        s.pauseCount += 1
        return (s, transitions)
    }

    func resume(_ session: FocusSession, at now: Date) -> FocusSession {
        var s = session
        guard s.state == .paused else { return s }
        s.phaseStartedAt = now
        s.pausedAt = nil
        s.state = .active
        return s
    }

    /// Starts the waiting phase when auto-start is off.
    func startNextPhase(_ session: FocusSession, at now: Date) -> (FocusSession, [TimerTransition]) {
        var s = session
        guard s.state == .active, s.isAwaitingNextPhase, s.phaseIndex + 1 < s.phases.count else { return (s, []) }
        s.phaseIndex += 1
        s.phaseStartedAt = now
        s.phaseAccumulated = 0
        s.isAwaitingNextPhase = false
        return (s, [.phaseStarted(index: s.phaseIndex, kind: s.phases[s.phaseIndex].kind, at: now)])
    }

    /// Ends a break early and starts the next focus block immediately.
    func skipBreak(_ session: FocusSession, at now: Date) -> (FocusSession, [TimerTransition]) {
        var (s, transitions) = advance(session, to: now)
        guard s.state.isLive else { return (s, transitions) }

        if s.isAwaitingNextPhase {
            // Waiting after a focus block: the upcoming break is skipped entirely.
            guard let next = s.nextPhase, next.kind.isBreak, s.phaseIndex + 2 < s.phases.count else { return (s, transitions) }
            s.phaseIndex += 2
        } else {
            guard let current = s.currentPhase, current.kind.isBreak, s.phaseIndex + 1 < s.phases.count else { return (s, transitions) }
            transitions.append(.phaseCompleted(index: s.phaseIndex, kind: current.kind, at: now))
            s.phaseIndex += 1
        }
        s.phaseStartedAt = now
        s.phaseAccumulated = 0
        s.isAwaitingNextPhase = false
        s.pausedAt = nil
        s.state = .active
        transitions.append(.phaseStarted(index: s.phaseIndex, kind: s.phases[s.phaseIndex].kind, at: now))
        return (s, transitions)
    }

    /// Finishes an open-ended (count-up) session. Sessions shorter than
    /// `TimerConfiguration.minimumCountUpCompletion` are recorded as abandoned.
    func finishCountUp(_ session: FocusSession, at now: Date) -> FocusSession {
        var (s, _) = advance(session, to: now)
        guard s.state.isLive, s.configuration.mode == .countUp else { return s }
        let focused = snapshot(of: s, at: now).totalFocusElapsed
        s.endedAt = now
        if focused >= TimerConfiguration.minimumCountUpCompletion {
            s.completedFocusDuration = focused
            s.completedFocusPhases = 1
            s.state = .completed
        } else {
            s.state = .abandoned
        }
        s.pausedAt = nil
        return s
    }

    /// Ends a session early. The result is `abandoned` unless the session had
    /// already completed by `now` (for example, the app was reopened late).
    func abandon(_ session: FocusSession, at now: Date) -> FocusSession {
        var (s, _) = advance(session, to: now)
        guard s.state.isLive else { return s }
        s.state = .abandoned
        s.endedAt = now
        s.pausedAt = nil
        return s
    }

    // MARK: - Scheduling

    /// Upcoming phase ends while the session runs, following auto-start rules.
    /// Stops at the first boundary that waits for the user or ends the session.
    func upcomingBoundaries(_ session: FocusSession, from now: Date) -> [PhaseBoundary] {
        let (s, _) = advance(session, to: now)
        guard s.state == .active, !s.isAwaitingNextPhase else { return [] }
        let phases = s.phases
        guard let currentDuration = phases[s.phaseIndex].duration else { return [] }

        var boundaries: [PhaseBoundary] = []
        var index = s.phaseIndex
        var endDate = s.phaseStartedAt.addingTimeInterval(currentDuration - s.phaseAccumulated)

        while boundaries.count < Self.maximumBoundaries {
            let nextIndex = index + 1
            let nextKind = phases.indices.contains(nextIndex) ? phases[nextIndex].kind : nil
            let waits = nextKind.map { !autoStarts($0, in: s.configuration) } ?? false
            boundaries.append(PhaseBoundary(
                date: endDate,
                endingPhaseIndex: index,
                endingKind: phases[index].kind,
                nextKind: nextKind,
                requiresUserToContinue: waits
            ))
            guard nextKind != nil, !waits, let nextDuration = phases[nextIndex].duration else { break }
            index = nextIndex
            endDate = endDate.addingTimeInterval(nextDuration)
        }
        return boundaries
    }

    // MARK: - Helpers

    func elapsedInPhase(_ session: FocusSession, at now: Date) -> TimeInterval {
        let running = session.state == .active && !session.isAwaitingNextPhase
        return session.phaseAccumulated + (running ? max(0, now.timeIntervalSince(session.phaseStartedAt)) : 0)
    }

    private func autoStarts(_ kind: FocusPhaseKind, in configuration: TimerConfiguration) -> Bool {
        kind == .focus ? configuration.autoStartFocus : configuration.autoStartBreaks
    }
}

// MARK: - FocusTimerService

import Foundation

/// The timer boundary used by the app. `FocusTimerEngine` is the V1
/// implementation: pure, date-based, and deterministic under an injected clock.
/// A future implementation could add, for example, routine-aware scheduling.
protocol FocusTimerService {
    func makeSession(
        id: UUID,
        configuration: TimerConfiguration,
        taskID: UUID?,
        sceneID: SceneID,
        renderMode: RenderMode,
        presetID: FocusPresetID,
        source: SessionSource,
        at now: Date
    ) -> FocusSession
    func advance(_ session: FocusSession, to now: Date) -> (FocusSession, [TimerTransition])
    func snapshot(of session: FocusSession, at now: Date) -> TimerSnapshot
    func pause(_ session: FocusSession, at now: Date) -> (FocusSession, [TimerTransition])
    func resume(_ session: FocusSession, at now: Date) -> FocusSession
    func startNextPhase(_ session: FocusSession, at now: Date) -> (FocusSession, [TimerTransition])
    func skipBreak(_ session: FocusSession, at now: Date) -> (FocusSession, [TimerTransition])
    func finishCountUp(_ session: FocusSession, at now: Date) -> FocusSession
    func abandon(_ session: FocusSession, at now: Date) -> FocusSession
    func upcomingBoundaries(_ session: FocusSession, from now: Date) -> [PhaseBoundary]
}

extension FocusTimerEngine: FocusTimerService {}

/// Formats durations for the timer face and stats. Display-only; never stored.
enum DurationFormatter {
    /// "24:59" or "1:04:10".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// Count-up clocks round down so the first second reads 00:00.
    static func elapsedClock(_ seconds: TimeInterval) -> String {
        clock(max(0, seconds.rounded(.down)))
    }

    /// "25 min", "1 h 5 min", "45 sec".
    static func short(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total) sec" }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        return "\(minutes) min"
    }

    /// VoiceOver-friendly: "12 minutes 30 seconds".
    static func spoken(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) \(hours == 1 ? "hour" : "hours")") }
        if minutes > 0 { parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }
        if secs > 0 || parts.isEmpty { parts.append("\(secs) \(secs == 1 ? "second" : "seconds")") }
        return parts.joined(separator: " ")
    }
}
