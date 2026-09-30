import SwiftUI
import UIKit
import WidgetKit

// Home-screen and Lock Screen summary. Reads the snapshot the app writes to
// the shared App Group (Shared/WidgetSnapshot.swift). Tapping it opens Still
// and starts the default preset.

struct FocusSummaryEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// False before the app has written anything (or without the App Group).
    let hasData: Bool
}

struct FocusSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusSummaryEntry {
        FocusSummaryEntry(date: Date(), snapshot: .placeholder, hasData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusSummaryEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusSummaryEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh just after midnight so "today" starts at zero; the app also
        // asks for a reload whenever its numbers change.
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: entry.date)) ?? entry.date.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(tomorrow.addingTimeInterval(60))))
    }

    private func currentEntry() -> FocusSummaryEntry {
        if let snapshot = WidgetSnapshotStore.load() {
            return FocusSummaryEntry(date: Date(), snapshot: snapshot, hasData: true)
        }
        return FocusSummaryEntry(date: Date(), snapshot: .placeholder, hasData: false)
    }
}

struct StillFocusSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotStore.summaryKind, provider: FocusSummaryProvider()) { entry in
            FocusSummaryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
                .widgetURL(URL(string: "still://start-focus?preset=default"))
        }
        .configurationDisplayName("Focus")
        .description("Today's focus and a one-tap start.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

/// A self-contained version of Still's soft-premium glow for the widget target.
/// The extension cannot import the app's SwiftUI design system.
enum WidgetPalette {
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.961, green: 0.933, blue: 0.972, alpha: 1)
            : UIColor(red: 0.180, green: 0.145, blue: 0.188, alpha: 1)
    })
    static let inkSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.785, green: 0.741, blue: 0.818, alpha: 1)
            : UIColor(red: 0.326, green: 0.291, blue: 0.352, alpha: 1)
    })
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.561, green: 0.863, blue: 0.753, alpha: 1)
            : UIColor(red: 0.243, green: 0.561, blue: 0.455, alpha: 1)
    })
    static let accentSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.235, green: 0.354, blue: 0.352, alpha: 1)
            : UIColor(red: 0.842, green: 0.937, blue: 0.897, alpha: 1)
    })
    static let onAccent = Color(red: 0.085, green: 0.150, blue: 0.124)
}

private struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.11, green: 0.10, blue: 0.20), Color(red: 0.20, green: 0.15, blue: 0.32)]
                : [Color(red: 0.98, green: 0.84, blue: 0.76), Color(red: 0.84, green: 0.91, blue: 0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(.white.opacity(colorScheme == .dark ? 0.06 : 0.30))
    }
}

struct FocusSummaryView: View {
    let entry: FocusSummaryEntry
    @Environment(\.widgetFamily) private var family

    private var todayMinutes: Int {
        Int((entry.snapshot.focus(on: entry.date) / 60).rounded())
    }

    private var todayText: String {
        let minutes = todayMinutes
        if minutes >= 60 {
            let hours = minutes / 60
            let rest = minutes % 60
            return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
        }
        return "\(minutes) min"
    }

    private var startText: String {
        entry.snapshot.defaultPresetMinutes > 0 ? "Start \(entry.snapshot.defaultPresetMinutes) min" : "Start"
    }

    private var streakText: String? {
        entry.snapshot.currentStreak >= 2 ? "\(entry.snapshot.currentStreak) days in a row" : nil
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Still", systemImage: "leaf")
                    .font(.caption.weight(.semibold))
                Text(entry.hasData ? "\(todayText) today" : "Tap to focus")
                    .font(.headline)
                if let streakText {
                    Text(streakText).font(.caption)
                }
            }
            .widgetAccentable()
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "leaf")
                        .font(.caption)
                    Text("\(todayMinutes)")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .minimumScaleFactor(0.6)
                }
            }
            .widgetAccentable()
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                summary
                VStack(alignment: .trailing, spacing: 8) {
                    WeekBars(minutes: entry.snapshot.lastSevenDays)
                        .frame(height: 54)
                    Spacer(minLength: 0)
                    startCapsule
                }
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                summary
                Spacer(minLength: 6)
                startCapsule
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Still", systemImage: "leaf")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(WidgetPalette.accent)
            Spacer(minLength: 4)
            Text(entry.snapshot.nextTaskTitle ?? (entry.hasData ? todayText : "Ready"))
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(WidgetPalette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(entry.snapshot.nextTaskTitle == nil ? (entry.hasData ? "focused today" : "when you are") : "Next thing · \(todayText) today")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(WidgetPalette.inkSecondary)
            if let streakText, family == .systemMedium {
                Text(streakText)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(WidgetPalette.inkSecondary)
                    .padding(.top, 2)
            }
        }
    }

    private var startCapsule: some View {
        Text(startText)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(WidgetPalette.onAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(WidgetPalette.accent))
            .accessibilityLabel("\(startText) of focus")
    }
}

/// Seven small bars, like the Me tab: a glance, not a chart.
struct WeekBars: View {
    let minutes: [Int]

    var body: some View {
        let peak = max(minutes.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(minutes.enumerated()), id: \.offset) { entry in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(entry.element > 0 ? WidgetPalette.accent : WidgetPalette.accentSoft)
                    .frame(width: 9, height: max(4, 54 * CGFloat(entry.element) / CGFloat(peak)))
            }
        }
        .accessibilityHidden(true)
    }
}
