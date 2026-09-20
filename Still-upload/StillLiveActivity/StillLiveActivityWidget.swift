// Optional widget extension for the Lock Screen and Dynamic Island.
//
// This folder is NOT part of the default Xcode project, so the app always
// builds without it. To enable Live Activities, follow README.md →
// "Enabling Live Activities". This target must also compile
// Still/Services/LiveActivity/LiveActivityShared.swift.
import ActivityKit
import SwiftUI
import WidgetKit

@main
struct StillLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        StillLiveActivityWidget()
    }
}

struct StillLiveActivityWidget: Widget {
    private let ink = Color(red: 0.98, green: 0.95, blue: 0.86)
    private let background = Color(red: 0.12, green: 0.15, blue: 0.22)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StillActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.state.isBreak ? "cup.and.saucer" : "leaf")
                    .font(.title2)
                    .foregroundStyle(ink.opacity(0.8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.headline)
                        .font(.headline)
                    Text(detail(context.state))
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.7))
                }
                Spacer()
                LiveTimerText(state: context.state)
                    .font(.system(.title, design: .rounded).weight(.light).monospacedDigit())
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
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(detail(context.state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer" : "leaf")
            } compactTrailing: {
                LiveTimerText(state: context.state)
                    .monospacedDigit()
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
