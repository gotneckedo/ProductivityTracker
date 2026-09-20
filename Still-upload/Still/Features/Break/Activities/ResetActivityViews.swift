import Foundation
import SwiftUI

/// Calls `onFinished` once when a fixed-length activity reaches its end.
private struct FinishWhenElapsed: ViewModifier {
    let startedAt: Date
    let duration: TimeInterval
    let isFinished: Bool
    let onFinished: () -> Void

    func body(content: Content) -> some View {
        content.task(id: isFinished) {
            guard !isFinished else { return }
            while !Task.isCancelled {
                if Date().timeIntervalSince(startedAt) >= duration {
                    await MainActor.run { onFinished() }
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}

// MARK: - Guided Stretch

struct GuidedStretchActivityView: View {
    let onFinished: () -> Void
    @State private var stepIndex = 0
    @State private var stepStartedAt = Date()
    @State private var isComplete = false

    private let routine = StretchRoutine.desk

    var body: some View {
        let step = routine.steps[min(stepIndex, routine.steps.count - 1)]
        let isLast = stepIndex >= routine.steps.count - 1
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            QuietNote(text: routine.safetyNote, symbol: "hand.raised")

            Text("Step \(stepIndex + 1) of \(routine.steps.count)")
                .font(StillTypography.footnote.weight(.medium))
                .foregroundStyle(StillTheme.textSecondary)
                .textCase(.uppercase)

            StillCard {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                    Text(step.title)
                        .font(StillTypography.title3)
                        .foregroundStyle(StillTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(step.instruction)
                        .font(StillTypography.body)
                        .foregroundStyle(StillTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .id(step.id)

            TimelineView(.periodic(from: stepStartedAt, by: 1)) { timeline in
                let remaining = max(0, step.duration - timeline.date.timeIntervalSince(stepStartedAt))
                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                    Text(remaining > 0 ? DurationFormatter.clock(remaining) : "Ready when you are")
                        .font(StillTypography.metric)
                        .foregroundStyle(StillTheme.textPrimary)
                    PixelProgressRow(progress: 1 - remaining / step.duration, count: 15)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step timer")
                .accessibilityValue(remaining > 0 ? "\(DurationFormatter.spoken(remaining)) left" : "Done")
            }

            Button(isLast ? "Finish" : "Next step") {
                if isLast {
                    isComplete = true
                    onFinished()
                } else {
                    stepIndex += 1
                    stepStartedAt = Date()
                }
            }
            .buttonStyle(QuietPrimaryButtonStyle())
            .disabled(isComplete)
        }
    }
}

// MARK: - Box Breathing

struct BoxBreathingActivityView: View {
    let startedAt: Date
    let isFinished: Bool
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pattern = BreathingPattern.box

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 24, paused: isFinished)) { timeline in
            let state = pattern.state(at: timeline.date.timeIntervalSince(startedAt))
            VStack(spacing: StillTheme.Spacing.l) {
                Text("Follow the square. Four counts each side.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    if reduceMotion {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(StillTheme.calm, lineWidth: 3)
                    } else {
                        BreathingSquare(stepIndex: state.stepIndex, stepProgress: state.stepProgress, isFinished: state.isFinished)
                    }
                    Text(isFinished ? "Done" : state.label)
                        .font(StillTypography.title)
                        .foregroundStyle(StillTheme.textPrimary)
                }
                .frame(width: 220, height: 220)
                .frame(maxWidth: .infinity)

                VStack(spacing: StillTheme.Spacing.xs) {
                    PixelProgressRow(progress: state.overallProgress, count: 16, filled: StillTheme.calm)
                    Text(isFinished ? "Two minutes, done." : "\(DurationFormatter.clock(state.remaining)) left")
                        .font(StillTypography.footnote.monospacedDigit())
                        .foregroundStyle(StillTheme.textSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Box breathing")
            .accessibilityValue(isFinished ? "Finished" : "\(state.label). \(DurationFormatter.spoken(state.remaining)) left")
            .accessibilityAddTraits(.updatesFrequently)
        }
        .modifier(FinishWhenElapsed(startedAt: startedAt, duration: pattern.totalDuration, isFinished: isFinished, onFinished: onFinished))
    }
}

/// A square outline with a small dot tracing it: up (inhale), across (hold),
/// down (exhale), back (hold). Slow, no scaling or pulsing.
private struct BreathingSquare: View {
    let stepIndex: Int
    let stepProgress: Double
    let isFinished: Bool

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 8
            let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
            let outline = Path(roundedRect: rect, cornerRadius: 18, style: .continuous)
            context.stroke(outline, with: .color(StillTheme.calmSoft), lineWidth: 6)

            let t = CGFloat(min(max(stepProgress, 0), 1))
            let point: CGPoint
            switch stepIndex {
            case 0: point = CGPoint(x: rect.minX, y: rect.maxY - rect.height * t)
            case 1: point = CGPoint(x: rect.minX + rect.width * t, y: rect.minY)
            case 2: point = CGPoint(x: rect.maxX, y: rect.minY + rect.height * t)
            default: point = CGPoint(x: rect.maxX - rect.width * t, y: rect.maxY)
            }
            guard !isFinished else { return }
            let dot = CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)
            context.fill(Path(ellipseIn: dot), with: .color(StillTheme.calm))
        }
    }
}

// MARK: - Do Nothing

struct DoNothingActivityView: View {
    let startedAt: Date
    let duration: TimeInterval
    let isFinished: Bool
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: StillTheme.Spacing.xl) {
            Spacer(minLength: StillTheme.Spacing.xl)
            Text(isFinished ? "That was the minute." : "Let your attention rest where it is.")
                .font(StillTypography.readingTitle)
                .foregroundStyle(StillTheme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !isFinished {
                TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
                    let remaining = max(0, duration - timeline.date.timeIntervalSince(startedAt))
                    Text(DurationFormatter.clock(remaining))
                        .font(StillTypography.footnote.monospacedDigit())
                        .foregroundStyle(StillTheme.textTertiary)
                        .accessibilityLabel("\(DurationFormatter.spoken(remaining)) left")
                }
            }
            Spacer(minLength: StillTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .modifier(FinishWhenElapsed(startedAt: startedAt, duration: duration, isFinished: isFinished, onFinished: onFinished))
    }
}

#Preview("Box breathing") {
    ActivityContainerView(activityID: .boxBreathing, context: .shelf)
        .environment(PreviewSupport.appState())
}
