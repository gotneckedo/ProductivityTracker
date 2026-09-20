import Foundation

/// A guided breathing pattern such as 4–4–4–4 box breathing.
struct BreathingPattern: Hashable {
    struct Step: Hashable {
        let label: String
        let duration: TimeInterval
    }

    let steps: [Step]
    let totalDuration: TimeInterval

    static let box = BreathingPattern(
        steps: [
            Step(label: "Inhale", duration: 4),
            Step(label: "Hold", duration: 4),
            Step(label: "Exhale", duration: 4),
            Step(label: "Hold", duration: 4)
        ],
        totalDuration: 120
    )

    var cycleDuration: TimeInterval { steps.reduce(0) { $0 + $1.duration } }

    struct State: Equatable {
        let stepIndex: Int
        let label: String
        /// 0...1 progress through the current step.
        let stepProgress: Double
        /// 0...1 progress through the whole exercise.
        let overallProgress: Double
        let remaining: TimeInterval
        let isFinished: Bool
    }

    func state(at elapsed: TimeInterval) -> State {
        let clamped = min(max(elapsed, 0), totalDuration)
        guard clamped < totalDuration else {
            return State(stepIndex: steps.count - 1, label: "Done", stepProgress: 1, overallProgress: 1, remaining: 0, isFinished: true)
        }
        var intoCycle = clamped.truncatingRemainder(dividingBy: cycleDuration)
        var index = 0
        while index < steps.count - 1, intoCycle >= steps[index].duration {
            intoCycle -= steps[index].duration
            index += 1
        }
        return State(
            stepIndex: index,
            label: steps[index].label,
            stepProgress: intoCycle / steps[index].duration,
            overallProgress: clamped / totalDuration,
            remaining: totalDuration - clamped,
            isFinished: false
        )
    }
}

struct StretchStep: Hashable, Identifiable {
    let id: String
    let title: String
    let instruction: String
    let duration: TimeInterval
}

/// Conservative, text-only stretching. Language stays gentle by design.
struct StretchRoutine: Hashable {
    let steps: [StretchStep]
    let safetyNote: String

    static let desk = StretchRoutine(
        steps: [
            StretchStep(
                id: "neck",
                title: "Neck release",
                instruction: "Sit tall. Let one ear drift toward its shoulder, only as far as feels easy. Breathe slowly. Switch sides halfway through.",
                duration: 30
            ),
            StretchStep(
                id: "shoulders",
                title: "Shoulder rolls",
                instruction: "Lift your shoulders toward your ears, roll them back, and let them settle down. Go slowly. After a few, reverse the direction.",
                duration: 30
            ),
            StretchStep(
                id: "side-reach",
                title: "Side reach",
                instruction: "Raise one arm and reach gently up and over to the other side. Keep it light. Switch arms halfway through.",
                duration: 30
            ),
            StretchStep(
                id: "hands",
                title: "Hands and wrists",
                instruction: "Open and close your hands a few times. Then circle your wrists slowly, first one way, then the other.",
                duration: 30
            )
        ],
        safetyNote: "Move only within your comfort. Stop if anything hurts."
    )

    var totalDuration: TimeInterval { steps.reduce(0) { $0 + $1.duration } }
}

/// Remaining time for a fixed-length activity, derived from its start date.
struct ActivityCountdown: Equatable {
    let startedAt: Date
    let duration: TimeInterval

    func remaining(at now: Date) -> TimeInterval {
        max(0, duration - now.timeIntervalSince(startedAt))
    }

    func progress(at now: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / duration))
    }

    func isFinished(at now: Date) -> Bool {
        remaining(at: now) <= 0
    }
}
