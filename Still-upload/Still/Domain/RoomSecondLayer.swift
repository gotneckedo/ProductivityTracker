import Foundation

/// The local facts a person sees by holding an object in the Focus room.
/// These are observations of existing on-device data, never progress demands,
/// score mechanics, or a second inventory system.
enum RoomSecondLayerTarget: String, CaseIterable, Hashable, Identifiable {
    case desk
    case books
    case plant
    case window
    case lamp
    case clock
    case calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .desk: return "Desk"
        case .books: return "Book spines"
        case .plant: return "Plant"
        case .window: return "Window"
        case .lamp: return "Lamp"
        case .clock: return "Wall clock"
        case .calendar: return "Wall calendar"
        }
    }

    var symbolName: String {
        switch self {
        case .desk: return "checklist"
        case .books: return "books.vertical"
        case .plant: return "leaf"
        case .window: return "window.vertical.open"
        case .lamp: return "lamp.desk"
        case .clock: return "clock"
        case .calendar: return "calendar"
        }
    }

    var destinationTitle: String {
        switch self {
        case .desk: return "Today’s tasks"
        case .books: return "Break"
        case .plant, .clock: return "Your days"
        case .window: return "Scenes"
        case .lamp: return "Session options"
        case .calendar: return "Today"
        }
    }
}

/// A compact, accessible description rendered by both the real context-menu
/// preview and the DEBUG review route. Keeping it platform-neutral makes the
/// facts testable without inventing a room state just for screenshots.
struct RoomSecondLayerFact: Equatable, Identifiable {
    let target: RoomSecondLayerTarget
    let detail: String
    let supportingDetail: String

    var id: RoomSecondLayerTarget { target }
    var title: String { target.title }
    var symbolName: String { target.symbolName }
    var accessibilityDescription: String { "\(title). \(detail) \(supportingDetail)" }
}

/// A single day in the calendar object’s seven-day local look-back.
struct RoomSecondLayerDay: Equatable {
    let day: Date
    let focusDuration: TimeInterval
}

/// A data-only snapshot of the objects currently visible in a room. It receives
/// all values from AppState; it does not persist, mutate, count attendance, or
/// make any promise about future unlocks.
struct RoomSecondLayerSnapshot: Equatable {
    let selectedTaskTitle: String?
    let books: [String]
    let plantStage: PlantGrowthStage
    let windowPhaseName: String
    let totalFocus: TimeInterval
    let weeklyFocus: [RoomSecondLayerDay]
    let now: Date
    let calendar: Calendar

    func fact(for target: RoomSecondLayerTarget) -> RoomSecondLayerFact {
        switch target {
        case .desk:
            let task = selectedTaskTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            return RoomSecondLayerFact(
                target: .desk,
                detail: task?.isEmpty == false ? "Next: \(task!)" : "The desk is clear.",
                supportingDetail: task?.isEmpty == false ? "Open Today’s tasks when you want to work on it." : "Open Today’s tasks to choose one."
            )
        case .books:
            let visibleTitles = books.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.prefix(2)
            let count = books.count
            let list = visibleTitles.isEmpty ? "No books on this shelf yet." : visibleTitles.joined(separator: " · ")
            return RoomSecondLayerFact(
                target: .books,
                detail: count == 1 ? "1 local book" : "\(count) local books",
                supportingDetail: "\(list) Open Break when you want a short passage."
            )
        case .plant:
            return RoomSecondLayerFact(
                target: .plant,
                detail: plantStage.roomDescription,
                supportingDetail: "It reflects completed sessions only. It never wilts or needs care."
            )
        case .window:
            let phase = windowPhaseName.replacingOccurrences(of: "_", with: " ").capitalized
            return RoomSecondLayerFact(
                target: .window,
                detail: "\(phase) view",
                supportingDetail: "The light and small window detail follow this device’s current time."
            )
        case .lamp:
            return RoomSecondLayerFact(
                target: .lamp,
                detail: lampWarmth(for: windowPhaseName),
                supportingDetail: "A quiet local warmth for this room; it does not indicate performance."
            )
        case .clock:
            return RoomSecondLayerFact(
                target: .clock,
                detail: clockString(now),
                supportingDetail: "\(DurationFormatter.short(totalFocus)) of completed focus kept on this device."
            )
        case .calendar:
            let activeDays = weeklyFocus.filter { $0.focusDuration > 0 }.count
            let total = weeklyFocus.reduce(0) { $0 + $1.focusDuration }
            return RoomSecondLayerFact(
                target: .calendar,
                detail: "\(DurationFormatter.short(total)) across \(activeDays) of the last 7 days",
                supportingDetail: calendarWeekLine
            )
        }
    }

    private var calendarWeekLine: String {
        guard !weeklyFocus.isEmpty else { return "No focus time in this seven-day view yet." }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EE")
        return weeklyFocus.map { day in
            "\(formatter.string(from: day.day)) \(day.focusDuration > 0 ? DurationFormatter.short(day.focusDuration) : "—")"
        }.joined(separator: " · ")
    }

    private func clockString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "It’s \(formatter.string(from: date))"
    }

    private func lampWarmth(for phase: String) -> String {
        switch phase.lowercased() {
        case "morning": return "Honey warmth"
        case "afternoon": return "Sunlit warmth"
        case "dusk": return "Rose-gold warmth"
        case "night", "focus": return "Low amber warmth"
        default: return "Warm desk light"
        }
    }
}

private extension PlantGrowthStage {
    var roomDescription: String {
        switch self {
        case .sprout: return "A small new sprout"
        case .leafy: return "A leafy little plant"
        case .full: return "A full, settled plant"
        }
    }
}
