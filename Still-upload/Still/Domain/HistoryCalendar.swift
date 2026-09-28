import Foundation

/// Calendar geometry for the local History screen. The model contains no score
/// or streak calculation: a marked date only says that Still has a saved local
/// record for that day.
struct HistoryCalendar {
    var calendar: Calendar

    func monthGrid(containing date: Date) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dates: [Date?] = Array(repeating: nil, count: leading) + range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
        let trailing = (7 - (dates.count % 7)) % 7
        return dates + Array(repeating: nil, count: trailing)
    }

    func markedDays(for dates: [Date]) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }
}
