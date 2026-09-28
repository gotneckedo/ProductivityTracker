import SwiftUI

/// Local focus and reflection history. Records are never scored; the calendar
/// simply marks days that contain something saved on this device.
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var filter: HistoryFilter = .all
    @State private var month = Date()

    private var records: [HistoryRecord] {
        let focus = appState.sessions
            .filter { $0.state == .completed }
            .map { session in
                HistoryRecord(
                    id: session.id,
                    date: session.endedAt ?? session.startedAt,
                    kind: .focus,
                    title: "Focus session",
                    detail: focusDetail(session)
                )
            }
        let journals = ([appState.journalToday].compactMap { $0 } + appState.journalPast)
            .map { entry in
                HistoryRecord(
                    id: entry.id,
                    date: entry.day,
                    kind: .journal,
                    title: entry.text,
                    detail: entry.mood.map { "Journal · \($0.displayName)" } ?? "Journal"
                )
            }
        return (focus + journals).sorted { $0.date > $1.date }
    }

    private var filteredRecords: [HistoryRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return records.filter { record in
            (filter.kind == nil || record.kind == filter.kind!) &&
            (trimmed.isEmpty || record.matches(trimmed))
        }
    }

    private var dayGroups: [HistoryDayGroup] {
        let calendar = appState.container.calendar
        let groups = Dictionary(grouping: filteredRecords) { calendar.startOfDay(for: $0.date) }
        return groups.map { HistoryDayGroup(day: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        StillScreen {
            historyContent
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search local history")
        .onAppear {
            month = appState.container.clock.now
            #if DEBUG || STILL_PROOF
            if DemoLaunch.requestedScreen == "history-search" {
                query = "focus"
            }
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Local history")
    }

    @ViewBuilder
    private var historyContent: some View {
        if records.isEmpty {
            EmptyState(
                symbol: "clock.arrow.circlepath",
                title: "Nothing saved yet",
                message: "Completed focus sessions and one-line journal entries will appear here."
            )
            .padding(.horizontal, StillTheme.Spacing.screen)
            .padding(.top, StillTheme.Spacing.xxl)
        } else {
            VStack(spacing: 0) {
                filterBar
                populatedHistoryContent
            }
        }
    }

    @ViewBuilder
    private var populatedHistoryContent: some View {
        if filteredRecords.isEmpty {
            EmptyState(
                symbol: "magnifyingglass",
                title: "No local matches",
                message: "Try a session, journal, or a different search word."
            )
            .padding(.horizontal, StillTheme.Spacing.screen)
            .padding(.top, StillTheme.Spacing.xxl)
        } else {
            historyList
        }
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: StillTheme.Spacing.l, pinnedViews: [.sectionHeaders]) {
                monthCalendar
                ForEach(dayGroups) { group in
                    historySection(group)
                }
                Color.clear.frame(height: 1).id("history-bottom")
            }
            .padding(.horizontal, StillTheme.Spacing.screen)
            .padding(.vertical, StillTheme.Spacing.m)
        }
        .stillScrollableViewport()
    }

    private func historySection(_ group: HistoryDayGroup) -> some View {
        Section {
            StillInsetList(padding: StillTheme.Spacing.s) {
                VStack(spacing: 0) {
                    ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                        HistoryRow(record: record)
                        if index < group.records.count - 1 {
                            InsetRowDivider(leading: 44)
                        }
                    }
                }
            }
        } header: {
            Text(group.day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(StillTypography.caption.weight(.semibold))
                .foregroundStyle(StillTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, StillTheme.Spacing.xs)
                .background(StillTheme.background.opacity(0.96))
        }
    }

    private var filterBar: some View {
        HStack(spacing: StillTheme.Spacing.xs) {
            ForEach(HistoryFilter.allCases, id: \.self) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.title)
                        .font(StillTypography.caption.weight(filter == option ? .semibold : .regular))
                        .foregroundStyle(filter == option ? StillTheme.textPrimary : StillTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: StillTheme.minimumTapSize)
                        .background(filter == option ? StillTheme.accentSoft.opacity(0.8) : .clear, in: Capsule())
                }
                .buttonStyle(StillRowButtonStyle())
                .accessibilityAddTraits(filter == option ? .isSelected : [])
            }
        }
        .padding(.horizontal, StillTheme.Spacing.screen)
        .padding(.vertical, StillTheme.Spacing.xs)
        .background(StillTheme.background.opacity(0.98))
    }

    private var monthCalendar: some View {
        let calendar = HistoryCalendar(calendar: appState.container.calendar)
        let cells = calendar.monthGrid(containing: month)
        let markedDays = calendar.markedDays(for: filteredRecords.map(\.date))
        let weekdaySymbols = appState.container.calendar.veryShortWeekdaySymbols
        return VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            HStack {
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(StillRowButtonStyle())
                    .accessibilityLabel("Previous month")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(StillTypography.title3)
                    .foregroundStyle(StillTheme.textPrimary)
                Spacer()
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(StillRowButtonStyle())
                    .accessibilityLabel("Next month")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textTertiary)
                        .frame(height: 18)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    HistoryCalendarCell(date: date, marked: date.map { markedDays.contains(appState.container.calendar.startOfDay(for: $0)) } ?? false)
                }
            }
            Text("A dot means there is a saved local entry for that day.")
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textSecondary)
        }
        .padding(StillTheme.Spacing.m)
        .background(StillTheme.surface, in: RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous))
    }

    private func changeMonth(_ delta: Int) {
        month = appState.container.calendar.date(byAdding: .month, value: delta, to: month) ?? month
    }

    private func focusDetail(_ session: FocusSession) -> String {
        let minutes = max(1, Int((session.countedFocusDuration / 60).rounded()))
        return "Focus · \(minutes) min"
    }
}

private enum HistoryFilter: CaseIterable, Hashable {
    case all
    case focus
    case journal

    var title: String {
        switch self {
        case .all: return "All"
        case .focus: return "Focus"
        case .journal: return "Journal"
        }
    }

    var kind: HistoryRecord.Kind? {
        switch self {
        case .all: return nil
        case .focus: return .focus
        case .journal: return .journal
        }
    }
}

private struct HistoryDayGroup: Identifiable {
    let day: Date
    let records: [HistoryRecord]
    var id: Date { day }
}

private struct HistoryRecord: Identifiable, Hashable {
    enum Kind: Hashable {
        case focus
        case journal

        var symbol: String {
            switch self {
            case .focus: return "timer"
            case .journal: return "text.book.closed"
            }
        }
    }

    let id: UUID
    let date: Date
    let kind: Kind
    let title: String
    let detail: String

    func matches(_ query: String) -> Bool {
        let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return [title, detail, date.formatted(.dateTime.month(.wide).day().year())]
            .contains { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle) }
    }
}

private struct HistoryCalendarCell: View {
    let date: Date?
    let marked: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(date.map { String(Calendar.current.component(.day, from: $0)) } ?? "")
                .font(StillTypography.caption.monospacedDigit())
                .foregroundStyle(date == nil ? .clear : StillTheme.textPrimary)
            Circle()
                .fill(marked ? StillTheme.accent : .clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: StillTheme.minimumTapSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.map { $0.formatted(.dateTime.month(.wide).day()) } ?? "")
        .accessibilityValue(marked ? "Has saved history" : "No saved history")
    }
}

private struct HistoryRow: View {
    let record: HistoryRecord

    var body: some View {
        HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
            Image(systemName: record.kind.symbol)
                .foregroundStyle(StillTheme.accent)
                .frame(width: 28, height: StillTheme.minimumTapSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                    .lineLimit(2)
                Text("\(record.detail) · \(record.date.formatted(.dateTime.hour().minute()))")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .stillInsetRow()
        .accessibilityElement(children: .combine)
    }
}
