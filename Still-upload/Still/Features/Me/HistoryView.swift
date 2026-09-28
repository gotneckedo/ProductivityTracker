import SwiftUI

/// An on-device search surface for saved focus sessions and one-line journal
/// entries. Block E expands this same route into the calendar-led history view;
/// the query is intentionally scoped to these records and never leaves Still.
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var query = ""

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
        guard !trimmed.isEmpty else { return records }
        return records.filter { $0.matches(trimmed) }
    }

    var body: some View {
        StillScreen {
            Group {
                if filteredRecords.isEmpty {
                    EmptyState(
                        symbol: query.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass",
                        title: query.isEmpty ? "Nothing saved yet" : "No local matches",
                        message: query.isEmpty
                            ? "Completed focus sessions and one-line journal entries will appear here."
                            : "Try a session title or a word from a journal line."
                    )
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.top, StillTheme.Spacing.xxl)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            Text("On this device")
                                .font(StillTypography.caption)
                                .tracking(1.1)
                                .foregroundStyle(StillTheme.textTertiary)
                            StillInsetList(padding: StillTheme.Spacing.s) {
                                VStack(spacing: 0) {
                                    ForEach(Array(filteredRecords.enumerated()), id: \.element.id) { index, record in
                                        HistoryRow(record: record)
                                        if index < filteredRecords.count - 1 {
                                            InsetRowDivider(leading: 44)
                                        }
                                    }
                                }
                            }
                            Color.clear.frame(height: 1).id("history-bottom")
                        }
                        .padding(.horizontal, StillTheme.Spacing.screen)
                        .padding(.vertical, StillTheme.Spacing.m)
                    }
                    .stillScrollableViewport()
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search local history")
        .onAppear {
            #if DEBUG || STILL_PROOF
            if DemoLaunch.requestedScreen == "history-search" {
                query = "study"
            }
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Local history")
    }

    private func focusDetail(_ session: FocusSession) -> String {
        let minutes = max(1, Int((session.countedFocusDuration / 60).rounded()))
        return "Focus · \(minutes) min"
    }
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
                Text("\(record.detail) · \(record.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .stillInsetRow()
        .accessibilityElement(children: .combine)
    }
}
