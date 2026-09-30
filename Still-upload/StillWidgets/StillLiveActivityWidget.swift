// The Lock Screen and Dynamic Island timer for a running session.
// Uses Still/Services/LiveActivity/LiveActivityShared.swift, which is shared
// with this target (see the project's membership exceptions).
import ActivityKit
import SwiftUI
import WidgetKit

struct StillLiveActivityWidget: Widget {
    private let ink = Color(red: 0.96, green: 0.93, blue: 0.97)
    private let accent = Color(red: 0.56, green: 0.86, blue: 0.75)
    private let background = Color(red: 0.07, green: 0.07, blue: 0.13)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StillActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.state.isBreak ? "cup.and.saucer" : "leaf")
                    .font(.title2)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.headline)
                        .font(.system(.headline, design: .serif))
                    Text(detail(context.state))
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.7))
                }
                Spacer()
                LiveTimerText(state: context.state)
                    .font(.system(.title, design: .serif).weight(.light).monospacedDigit())
            }
            .foregroundStyle(ink)
            .padding(16)
            .activityBackgroundTint(background)
            .activitySystemActionForegroundColor(ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.headline, systemImage: context.state.isBreak ? "cup.and.saucer" : "leaf")
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveTimerText(state: context.state)
                        .font(.system(.title3, design: .serif).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(detail(context.state))
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.7))
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer" : "leaf")
            } compactTrailing: {
                LiveTimerText(state: context.state)
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "leaf")
            }
        }
    }

    private func detail(_ state: LiveActivityState) -> String {
        if state.focusBlockCount > 1 {
            return "\(state.sceneName) · Block \(state.focusBlockNumber) of \(state.focusBlockCount)"
        }
        return state.sceneName
    }
}

/// A system-driven timer, so the Lock Screen stays accurate without updates.
struct LiveTimerText: View {
    let state: LiveActivityState

    var body: some View {
        if let end = state.phaseEndDate, end > Date() {
            Text(timerInterval: Date()...end, countsDown: true)
        } else if let start = state.countUpStartDate {
            Text(start, style: .timer)
        } else {
            Text(Self.format(state.frozenSeconds ?? 0))
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
