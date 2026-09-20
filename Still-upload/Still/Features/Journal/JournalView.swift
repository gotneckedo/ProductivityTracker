import SwiftUI

/// One line a day, and a short list of small habits. Nothing here is scored,
/// and missing a day is never mentioned.
struct JournalView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Journal")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("One line a day is plenty.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    TodayLineCard()
                    HabitsSection()
                    PastLinesSection()
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.top, StillTheme.Spacing.m)
                .padding(.bottom, StillTheme.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Today's line

private struct TodayLineCard: View {
    @Environment(AppState.self) private var appState
    @State private var text = ""
    @State private var mood: JournalMood?
    @State private var hasLoaded = false
    @FocusState private var isEditing: Bool

    private var saved: JournalEntry? { appState.journalToday }

    private var isDirty: Bool {
        JournalController.normalized(text) != (saved?.text ?? "") || mood != saved?.mood
    }

    var body: some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(StillTypography.footnote.weight(.medium))
                    .foregroundStyle(StillTheme.textSecondary)
                TextField("How was today, in one line?", text: $text, axis: .vertical)
                    .font(StillTypography.reading)
                    .foregroundStyle(StillTheme.textPrimary)
                    .lineLimit(1...4)
                    .submitLabel(.done)
                    .focused($isEditing)
                    .onChange(of: text) { _, newValue in
                        // Return saves instead of starting a new line.
                        if newValue.contains("\n") {
                            text = newValue.replacingOccurrences(of: "\n", with: " ")
                            save()
                        } else if newValue.count > JournalEntry.maximumLength {
                            text = String(newValue.prefix(JournalEntry.maximumLength))
                        }
                    }
                    .accessibilityLabel("Today's line")

                HStack(spacing: StillTheme.Spacing.xs) {
                    ForEach(JournalMood.allCases, id: \.self) { option in
                        MoodChip(mood: option, isSelected: mood == option) {
                            mood = mood == option ? nil : option
                            save()
                        }
                    }
                }

                HStack {
                    if saved != nil && !isDirty {
                        Label("Saved on this device", systemImage: "checkmark")
                            .font(StillTypography.caption)
                            .foregroundStyle(StillTheme.textTertiary)
                    } else {
                        Text("\(text.count)/\(JournalEntry.maximumLength)")
                            .font(StillTypography.caption.monospacedDigit())
                            .foregroundStyle(StillTheme.textTertiary)
                    }
                    Spacer()
                    if isDirty {
                        Button("Save", action: save)
                            .buttonStyle(QuietSecondaryButtonStyle())
                    }
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: appState.journalToday) { _, _ in
            if !isEditing { load() }
        }
    }

    private func load() {
        guard !isEditing else { return }
        text = saved?.text ?? ""
        mood = saved?.mood
        hasLoaded = true
    }

    private func save() {
        appState.saveJournal(text: text, mood: mood)
        isEditing = false
    }
}

private struct MoodChip: View {
    let mood: JournalMood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(mood.displayName, systemImage: mood.symbolName)
                .labelStyle(.titleAndIcon)
                .font(StillTypography.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? StillTheme.textPrimary : StillTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, StillTheme.Spacing.xs)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Capsule(style: .continuous).fill(isSelected ? StillTheme.accentSoft : StillTheme.surfaceSunken))
                .overlay(Capsule(style: .continuous).strokeBorder(isSelected ? StillTheme.accent : Color.clear, lineWidth: StillTheme.Stroke.hairline))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Feeling: \(mood.displayName)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Habits

struct HabitsSection: View {
    @Environment(AppState.self) private var appState
    @State private var newTitle = ""
    @State private var renaming: HabitDefinition?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Small habits", detail: "Tap to mark today. A missed day doesn't count against anything.")
            StillCard {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                    if appState.habitDays.isEmpty {
                        Text("Try one or two: water the plants, a short walk, read a page.")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(appState.habitDays) { day in
                        HabitRow(day: day) {
                            appState.toggleHabit(day.habit.id)
                        }
                        .contextMenu {
                            Button {
                                renameText = day.habit.title
                                renaming = day.habit
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                appState.archiveHabit(day.habit.id)
                            } label: {
                                Label("Remove from list", systemImage: "archivebox")
                            }
                        }
                        if day.id != appState.habitDays.last?.id {
                            Divider()
                        }
                    }
                    if appState.canAddHabit {
                        if !appState.habitDays.isEmpty { Divider() }
                        HStack(spacing: StillTheme.Spacing.s) {
                            Image(systemName: "plus")
                                .foregroundStyle(StillTheme.textTertiary)
                                .accessibilityHidden(true)
                            TextField("Add a habit", text: $newTitle)
                                .font(StillTypography.body)
                                .submitLabel(.done)
                                .onSubmit(add)
                            if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                Button("Add", action: add)
                                    .font(StillTypography.callout.weight(.semibold))
                            }
                        }
                        .frame(minHeight: StillTheme.minimumTapSize)
                    } else {
                        Text("Five is the limit, so the list stays light.")
                            .font(StillTypography.caption)
                            .foregroundStyle(StillTheme.textTertiary)
                    }
                }
            }
        }
        .alert("Rename habit", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let habit = renaming { appState.renameHabit(habit.id, to: renameText) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func add() {
        if appState.addHabit(title: newTitle) {
            newTitle = ""
        }
    }
}

private struct HabitRow: View {
    let day: HabitDay
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: StillTheme.Spacing.s) {
                Image(systemName: day.isDoneToday ? "checkmark.circle.fill" : "circle")
                    .font(StillTypography.title3)
                    .foregroundStyle(day.isDoneToday ? StillTheme.accent : StillTheme.textTertiary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.habit.title)
                        .font(StillTypography.body)
                        .foregroundStyle(StillTheme.textPrimary)
                    if let run = HabitController.runLine(day.currentRun) {
                        Text(run)
                            .font(StillTypography.caption)
                            .foregroundStyle(StillTheme.textTertiary)
                    }
                }
                Spacer(minLength: StillTheme.Spacing.xs)
                HStack(spacing: 3) {
                    ForEach(Array(day.lastSevenDays.enumerated()), id: \.offset) { entry in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(entry.element ? StillTheme.accent : StillTheme.border)
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(minHeight: StillTheme.minimumTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.habit.title)
        .accessibilityValue(day.isDoneToday ? "Done today" : "Not yet today")
        .accessibilityHint("Double-tap to change today. Long-press for more.")
    }
}

// MARK: - Earlier lines

private struct PastLinesSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Earlier", detail: runDetail)
            if appState.journalPast.isEmpty {
                QuietNote(text: "Lines from earlier days will collect here. They stay on this device.", symbol: "book.closed")
            } else {
                StillCard {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        ForEach(appState.journalPast) { entry in
                            PastLineRow(entry: entry)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        appState.deleteJournalEntry(entry.id)
                                    } label: {
                                        Label("Delete line", systemImage: "trash")
                                    }
                                }
                            if entry.id != appState.journalPast.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var runDetail: String? {
        let run = appState.journalRun
        return run >= 2 ? "You've written \(run) days in a row." : nil
    }
}

private struct PastLineRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StillTheme.Spacing.s) {
            Text(entry.day.formatted(.dateTime.month(.abbreviated).day()))
                .font(StillTypography.caption.monospacedDigit())
                .foregroundStyle(StillTheme.textTertiary)
                .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(StillTypography.callout)
                        .foregroundStyle(StillTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let mood = entry.mood {
                    Label(mood.displayName, systemImage: mood.symbolName)
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Journal") {
    NavigationStack {
        JournalView()
    }
    .environment(PreviewSupport.appState(populated: true))
}
