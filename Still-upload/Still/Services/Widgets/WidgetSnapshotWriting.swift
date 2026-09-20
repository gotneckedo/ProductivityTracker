import Foundation

/// Publishes the home-screen widget's data. The live writer saves to the
/// shared App Group and asks WidgetKit to refresh.
protocol WidgetSnapshotWriting: AnyObject {
    func write(_ snapshot: WidgetSnapshot)
}

final class RecordingWidgetSnapshotWriter: WidgetSnapshotWriting {
    private(set) var lastSnapshot: WidgetSnapshot?
    private(set) var writeCount = 0

    func write(_ snapshot: WidgetSnapshot) {
        lastSnapshot = snapshot
        writeCount += 1
    }
}

/// Builds the widget's snapshot from app state. Only titles the user chose to
/// focus on appear; no journal text, notes, or habits.
enum WidgetSnapshotBuilder {
    static func snapshot(
        stats: FocusStats,
        preset: FocusPreset,
        nextTask: TaskItem?,
        now: Date,
        calendar: Calendar
    ) -> WidgetSnapshot {
        let minutes = stats.lastSevenDays.map { Int(($0.focusDuration / 60).rounded()) }
        let presetMinutes = preset.timer.mode == .countUp ? 0 : Int((preset.timer.focusDuration / 60).rounded())
        return WidgetSnapshot(
            generatedAt: now,
            day: calendar.startOfDay(for: now),
            todayFocus: stats.todayFocus,
            currentStreak: stats.currentStreak,
            completedSessions: stats.completedSessions,
            defaultPresetName: preset.name,
            defaultPresetMinutes: presetMinutes,
            nextTaskTitle: nextTask?.title,
            lastSevenDays: minutes
        )
    }
}

#if canImport(WidgetKit) && os(iOS)
import WidgetKit

final class AppGroupWidgetSnapshotWriter: WidgetSnapshotWriting {
    private var lastWritten: WidgetSnapshot?

    func write(_ snapshot: WidgetSnapshot) {
        // Skip identical writes (generatedAt aside) so reloads stay rare.
        var comparable = snapshot
        comparable.generatedAt = lastWritten?.generatedAt ?? snapshot.generatedAt
        guard comparable != lastWritten else { return }
        lastWritten = snapshot
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.summaryKind)
    }
}
#endif
