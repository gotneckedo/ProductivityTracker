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
                    WidgetPalette.background
                }
                .widgetURL(URL(string: "still://start-focus?preset=default"))
        }
        .configurationDisplayName("Focus")
        .description("Today's focus and a one-tap start.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

/// Fixed pastel tones that read well on the home screen in both appearances.
enum WidgetPalette {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.106, green: 0.122, blue: 0.169, alpha: 1)
            : UIColor(red: 0.969, green: 0.949, blue: 0.918, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.925, green: 0.902, blue: 0.863, alpha: 1)
            : UIColor(red: 0.169, green: 0.192, blue: 0.251, alpha: 1)
    })
    static let inkSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.725, green: 0.702, blue: 0.663, alpha: 1)
            : UIColor(red: 0.357, green: 0.380, blue: 0.447, alpha: 1)
    })
    static let sage = Color(red: 0.561, green: 0.686, blue: 0.541)
    static let sageSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.180, green: 0.231, blue: 0.192, alpha: 1)
            : UIColor(red: 0.878, green: 0.918, blue: 0.859, alpha: 1)
    })
    static let onSage = Color(red: 0.137, green: 0.161, blue: 0.122)
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
                .foregroundStyle(WidgetPalette.sage)
            Spacer(minLength: 4)
            Text(entry.hasData ? todayText : "Ready")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(WidgetPalette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(entry.hasData ? "focused today" : "when you are")
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
            .foregroundStyle(WidgetPalette.onSage)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(WidgetPalette.sage))
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
                    .fill(entry.element > 0 ? WidgetPalette.sage : WidgetPalette.sageSoft)
                    .frame(width: 9, height: max(4, 54 * CGFloat(entry.element) / CGFloat(peak)))
            }
        }
        .accessibilityHidden(true)
    }
}
