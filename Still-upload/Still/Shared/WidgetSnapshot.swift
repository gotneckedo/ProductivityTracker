import Foundation

// Compiled into the app AND the StillWidgets extension, so Foundation only.

/// What the home-screen widget shows. Written by the app whenever its data
/// changes; read by the widget without the app running.
struct WidgetSnapshot: Codable, Hashable {
    var generatedAt: Date
    /// Start of the day `todayFocus` belongs to, so a stale value isn't shown tomorrow.
    var day: Date
    var todayFocus: TimeInterval
    var currentStreak: Int
    var completedSessions: Int
    var defaultPresetName: String
    var defaultPresetMinutes: Int
    var nextTaskTitle: String?
    /// Last seven days of focus, oldest first, in minutes.
    var lastSevenDays: [Int]

    static let placeholder = WidgetSnapshot(
        generatedAt: Date(timeIntervalSinceReferenceDate: 0),
        day: Date(timeIntervalSinceReferenceDate: 0),
        todayFocus: 50 * 60,
        currentStreak: 3,
        completedSessions: 9,
        defaultPresetName: "Default",
        defaultPresetMinutes: 25,
        nextTaskTitle: nil,
        lastSevenDays: [25, 50, 0, 25, 75, 50, 50]
    )

    /// Today's focus, or zero if the snapshot is from an earlier day.
    func focus(on now: Date, calendar: Calendar = .current) -> TimeInterval {
        calendar.isDate(day, inSameDayAs: now) ? todayFocus : 0
    }
}

/// Shared storage between the app and the widget (an App Group).
enum WidgetSnapshotStore {
    static let appGroup = "group.com.cocomedia.still"
    static let key = "still.widget.snapshot.v1"
    /// Widget kinds, so the app can ask WidgetKit to refresh them.
    static let summaryKind = "StillFocusSummary"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func load(from defaults: UserDefaults? = WidgetSnapshotStore.defaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = WidgetSnapshotStore.defaults) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }
}
