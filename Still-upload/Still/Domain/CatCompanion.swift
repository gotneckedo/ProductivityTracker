import Foundation

/// A room companion is ambient, never a care mechanic. These states only choose
/// an authored pose; they do not introduce hunger, mood, decay, scores, or any
/// action the person must take for the cat.
enum CatRoomState: String, Codable, CaseIterable, Equatable {
    case idle
    case morning
    case exploring
    case walkingToDesk
    case focus
    case sleeping
    case nightSleeping
    case finalMinute
    case breakTime
    case complete

    var accessibilityDescription: String {
        switch self {
        case .idle: return "resting nearby"
        case .morning: return "awake for the morning"
        case .exploring: return "exploring the room"
        case .walkingToDesk: return "walking toward the desk"
        case .focus: return "settled at the desk"
        case .sleeping: return "curled up asleep"
        case .nightSleeping: return "curled up for the night"
        case .finalMinute: return "stretching as the session settles"
        case .breakTime: return "heading toward the bookshelf"
        case .complete: return "awake and looking up"
        }
    }
}

/// Each pose is one cell in Still's original 3×2 cat sheet. The same semantic
/// map is used for every coat, so a cosmetic choice never changes behavior.
enum CatPose: Int, CaseIterable, Equatable {
    case sit = 0
    case idle = 1
    case walk = 2
    case sleep = 3
    case stretch = 4
    case lookUp = 5
}

enum CatReaction: Equatable {
    case none
    case ordinary
    case rare
}

struct CatAnimationPlan: Equatable {
    let poses: [CatPose]
    let secondsPerPose: TimeInterval

    func pose(at step: Int) -> CatPose {
        poses[abs(step) % poses.count]
    }
}

enum CatCompanion {
    static let sleepThreshold: TimeInterval = 10 * 60
    static let arrivalDuration: TimeInterval = 3
    static let finalMinuteThreshold: TimeInterval = 2 * 60
    static let awayThreshold: TimeInterval = 4 * 60 * 60

    static func state(
        isCompletion: Bool = false,
        isFocusRunning: Bool = false,
        isBreakPhase: Bool = false,
        focusedSeconds: TimeInterval = 0,
        remainingFocusSeconds: TimeInterval? = nil,
        isReturningAfterLongAway: Bool = false,
        isChangingRoom: Bool = false,
        hour: Int
    ) -> CatRoomState {
        if isCompletion { return .complete }
        if isBreakPhase { return .breakTime }
        if isFocusRunning {
            if (remainingFocusSeconds ?? .infinity) <= finalMinuteThreshold { return .finalMinute }
            if focusedSeconds < arrivalDuration { return .walkingToDesk }
            if focusedSeconds >= sleepThreshold { return .sleeping }
            return .focus
        }
        if isChangingRoom || isReturningAfterLongAway { return .exploring }
        if hour >= 21 || hour < 5 { return .nightSleeping }
        if (5..<12).contains(hour) { return .morning }
        return .idle
    }

    static func wasAway(since lastPresenceAt: Date?, now: Date) -> Bool {
        guard let lastPresenceAt else { return false }
        return now.timeIntervalSince(lastPresenceAt) >= awayThreshold
    }

    static func animation(for state: CatRoomState, reaction: CatReaction = .none) -> CatAnimationPlan {
        switch reaction {
        case .ordinary:
            return CatAnimationPlan(poses: [.lookUp, .stretch, .sit], secondsPerPose: 0.38)
        case .rare:
            return CatAnimationPlan(poses: [.stretch, .lookUp, .sleep, .sit], secondsPerPose: 0.32)
        case .none:
            break
        }

        switch state {
        case .idle:
            return CatAnimationPlan(poses: [.sit, .idle], secondsPerPose: 2.4)
        case .morning:
            return CatAnimationPlan(poses: [.sit, .idle], secondsPerPose: 2.8)
        case .exploring:
            return CatAnimationPlan(poses: [.walk, .walk, .sit], secondsPerPose: 1.0)
        case .walkingToDesk:
            return CatAnimationPlan(poses: [.walk, .walk, .walk, .idle, .idle, .idle], secondsPerPose: 0.5)
        case .focus:
            return CatAnimationPlan(poses: [.idle], secondsPerPose: 2.4)
        case .sleeping:
            return CatAnimationPlan(poses: [.sleep], secondsPerPose: 2.4)
        case .nightSleeping:
            return CatAnimationPlan(poses: [.sleep], secondsPerPose: 2.8)
        case .finalMinute:
            return CatAnimationPlan(poses: [.stretch, .idle], secondsPerPose: 1.1)
        case .breakTime:
            return CatAnimationPlan(poses: [.walk, .sit], secondsPerPose: 1.2)
        case .complete:
            return CatAnimationPlan(poses: [.lookUp, .stretch, .idle], secondsPerPose: 0.65)
        }
    }
}

/// Keeps the triple-tap discovery deterministic and local. It is deliberately
/// a small visual reaction rather than a reward or progression event.
struct CatTapTracker: Equatable {
    private(set) var recentTapTimes: [Date] = []
    static let rareReactionWindow: TimeInterval = 3

    mutating func registerTap(at date: Date) -> CatReaction {
        recentTapTimes = recentTapTimes.filter {
            date.timeIntervalSince($0) <= Self.rareReactionWindow
        }
        recentTapTimes.append(date)
        return recentTapTimes.count >= 3 ? .rare : .ordinary
    }
}

/// Normalization is shared by persistence and UI so a name remains optional,
/// device-local, and bounded even when records are restored from older builds.
enum CatName {
    static let maximumLength = 18

    static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumLength))
    }
}

/// Ginger is the starter cat. Other authored coats are an optional Still+ visual
/// choice; the cat itself and every focus behavior stay free and offline.
enum CatAppearanceAccess {
    static func canUse(_ coat: CatCoat, hasStillPlus: Bool) -> Bool {
        coat == .ginger || hasStillPlus
    }
}
