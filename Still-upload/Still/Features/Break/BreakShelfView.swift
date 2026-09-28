import SwiftUI

/// A finite shelf of small alternatives. It is organized as two calm activity
/// lists rather than a feed of independently floating recommendation cards.
struct BreakShelfView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedCategory: ActivityCategory?
    @State private var isEditingShelf = false
    @State private var draftOrder: [BreakActivityID] = []
    @State private var draftHidden: Set<BreakActivityID> = []
    @State private var suggestionOffset = 0
    @State private var didReshuffle = false

    private var visibleActivities: [BreakActivity] {
        let ranked = BreakShelfRanking().ranked(
            // The shelf is finite, but every locally implemented activity is
            // available from it. Suggestions may rank a smaller set; they do
            // not hide working alternatives.
            catalog: ActivityCatalog.available,
            usages: appState.usages,
            personalization: appState.personalization
        )
        let ordered = orderedActivities(ranked)
        let visible = isEditingShelf ? ordered : ordered.filter { !appState.breakShelfHiddenIDs.contains($0.id) }
        return selectedCategory.map { category in visible.filter { $0.category == category } } ?? visible
    }

    private var pickedActivities: [BreakActivity] {
        Array(visibleActivities.prefix(2))
    }

    private var remainingActivities: [BreakActivity] {
        Array(visibleActivities.dropFirst(pickedActivities.count))
    }

    var body: some View {
        StillScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                        header
                        if didReshuffle && !isEditingShelf {
                            QuietNote(text: "Fresh suggestions, still finite.", symbol: "arrow.clockwise")
                                .transition(.opacity)
                        }
                        categoryControls
                        if isEditingShelf {
                            shelfEditor
                        } else {
                            activityGroup(title: "Picked for you", activities: pickedActivities, tint: StillTheme.calmSoft)
                        }
                        if !isEditingShelf, !remainingActivities.isEmpty {
                            activityGroup(
                                title: selectedCategory == nil ? "Everything else" : "More options",
                                activities: remainingActivities,
                                tint: StillTheme.warmSoft
                            )
                        }
                        Color.clear.frame(height: 1).id("break-bottom")
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                }
                .stillScrollableViewport()
                .refreshable { reshuffleSuggestions() }
                .onAppear {
                    #if DEBUG || STILL_PROOF
                    if DemoLaunch.shouldScrollToBottom("break") {
                        DispatchQueue.main.async { proxy.scrollTo("break-bottom", anchor: .bottom) }
                    }
                    #endif
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            resetDraft()
            #if DEBUG || STILL_PROOF
            if DemoLaunch.requestedScreen == "break-edit" {
                isEditingShelf = true
            } else if DemoLaunch.requestedScreen == "break-reshuffled" {
                suggestionOffset = 1
                didReshuffle = true
            }
            #endif
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            Text(Copy.BreakShelf.eyebrow)
                .font(StillTypography.caption)
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(StillTheme.textTertiary)
            HStack(alignment: .firstTextBaseline) {
                Text(Copy.BreakShelf.title)
                    .font(StillTypography.display)
                    .foregroundStyle(StillTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(isEditingShelf ? "Done" : "Edit") {
                    if isEditingShelf {
                        appState.setBreakShelf(order: draftOrder, hidden: draftHidden)
                    } else {
                        resetDraft()
                    }
                    isEditingShelf.toggle()
                }
                .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
            }
        }
    }

    private var categoryControls: some View {
        GlassControlGroup(padding: StillTheme.Spacing.xs, radius: StillTheme.Radius.medium) {
            if dynamicTypeSize.isAccessibilitySize {
                Menu {
                    Button(Copy.BreakShelf.all) { selectCategory(nil) }
                    ForEach(ActivityCategory.allCases, id: \.self) { category in
                        Button(category.displayName) { selectCategory(category) }
                    }
                } label: {
                    HStack(spacing: StillTheme.Spacing.xs) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedCategory?.displayName ?? Copy.BreakShelf.all)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: StillTheme.minimumTapSize)
                    .padding(.horizontal, StillTheme.Spacing.s)
                }
                .accessibilityLabel("Break category")
                .accessibilityValue(selectedCategory?.displayName ?? Copy.BreakShelf.all)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StillTheme.Spacing.xs) {
                        ShelfFilter(title: Copy.BreakShelf.all, isSelected: selectedCategory == nil) {
                            selectCategory(nil)
                        }
                        ForEach(ActivityCategory.allCases, id: \.self) { category in
                            ShelfFilter(title: category.displayName, isSelected: selectedCategory == category) {
                                selectCategory(category)
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectCategory(_ category: ActivityCategory?) {
        selectedCategory = category
        StillInteractionFeedback.fire(.roomChanged, preferences: appState.preferences)
    }

    private var shelfEditor: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Arrange shelf", detail: "Move a row, or hide it. Hidden activities stay here to restore anytime.")
            MatteActivityCanvas(tint: StillTheme.calmSoft, radius: StillTheme.Radius.large) {
                VStack(spacing: 0) {
                    ForEach(Array(editableActivities.enumerated()), id: \.element.id) { index, activity in
                        HStack(spacing: StillTheme.Spacing.s) {
                            Image(systemName: draftHidden.contains(activity.id) ? "eye.slash" : activity.symbolName)
                                .foregroundStyle(draftHidden.contains(activity.id) ? StillTheme.textTertiary : StillTheme.calm)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.name).font(StillTypography.bodyEmphasis).foregroundStyle(StillTheme.textPrimary)
                                Text(draftHidden.contains(activity.id) ? "Hidden — restore when you want it" : "Shown on your shelf")
                                    .font(StillTypography.caption).foregroundStyle(StillTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Button { move(activity.id, by: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(StillRowButtonStyle())
                                .disabled(index == 0)
                                .accessibilityLabel("Move \(activity.name) earlier")
                            Button { move(activity.id, by: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(StillRowButtonStyle())
                                .disabled(index == editableActivities.count - 1)
                                .accessibilityLabel("Move \(activity.name) later")
                            Button {
                                if draftHidden.contains(activity.id) { draftHidden.remove(activity.id) }
                                else { draftHidden.insert(activity.id) }
                            } label: {
                                Image(systemName: draftHidden.contains(activity.id) ? "eye" : "eye.slash")
                            }
                            .buttonStyle(StillRowButtonStyle())
                            .accessibilityLabel(draftHidden.contains(activity.id) ? "Show \(activity.name)" : "Hide \(activity.name)")
                        }
                        .stillInsetRow(verticalPadding: StillTheme.Spacing.xs)
                        if index < editableActivities.count - 1 { InsetRowDivider(leading: 42) }
                    }
                }
            }
        }
    }

    private var editableActivities: [BreakActivity] {
        let byID = Dictionary(uniqueKeysWithValues: ActivityCatalog.available.map { ($0.id, $0) })
        return draftOrder.compactMap { byID[$0] }
    }

    private func orderedActivities(_ ranked: [BreakActivity]) -> [BreakActivity] {
        guard !appState.breakShelfCustomOrder.isEmpty else {
            guard !ranked.isEmpty else { return [] }
            return BreakShelfRotation.rotated(ranked, offset: suggestionOffset)
        }
        let byID = Dictionary(uniqueKeysWithValues: ranked.map { ($0.id, $0) })
        let chosen = appState.breakShelfCustomOrder.compactMap { byID[$0] }
        let remaining = ranked.filter { !appState.breakShelfCustomOrder.contains($0.id) }
        return chosen + remaining
    }

    private func resetDraft() {
        let defaults = ActivityCatalog.available.map(\.id)
        let current = appState.breakShelfCustomOrder
        draftOrder = current.isEmpty ? defaults : current + defaults.filter { !current.contains($0) }
        draftHidden = appState.breakShelfHiddenIDs
    }

    private func move(_ id: BreakActivityID, by delta: Int) {
        guard let index = draftOrder.firstIndex(of: id) else { return }
        let destination = index + delta
        guard draftOrder.indices.contains(destination) else { return }
        draftOrder.swapAt(index, destination)
    }

    private func reshuffleSuggestions() {
        guard appState.breakShelfCustomOrder.isEmpty else {
            withAnimation(.easeInOut(duration: 0.18)) { didReshuffle = true }
            return
        }
        let count = max(1, ActivityCatalog.available.count)
        suggestionOffset = (suggestionOffset + 1) % count
        withAnimation(.easeInOut(duration: 0.18)) { didReshuffle = true }
    }

    @ViewBuilder
    private func activityGroup(title: String, activities: [BreakActivity], tint: Color) -> some View {
        if !activities.isEmpty {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                SectionHeader(title: title)
                MatteActivityCanvas(tint: tint, radius: StillTheme.Radius.large) {
                    VStack(spacing: 0) {
                        ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                            Button {
                                appState.router.go(to: .breakActivity(activity.id, .shelf))
                            } label: {
                                ActivityTile(
                                    activity: activity,
                                    isDoneToday: appState.activityStatus(for: activity.id).kind == .completed
                                )
                            }
                            .buttonStyle(StillRowButtonStyle())
                            .contextMenu {
                                Button("Open \(activity.name)") {
                                    appState.router.go(to: .breakActivity(activity.id, .shelf))
                                }
                            } preview: {
                                BreakActivityContextPreview(activity: activity)
                            }
                            if index < activities.count - 1 {
                                InsetRowDivider(leading: 58)
                            }
                        }
                    }
                    .padding(.horizontal, StillTheme.Spacing.s)
                    .padding(.vertical, StillTheme.Spacing.xs)
                }
            }
        }
    }
}

private struct BreakActivityContextPreview: View {
    let activity: BreakActivity

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            Image(systemName: activity.symbolName)
                .font(StillTypography.title3)
                .foregroundStyle(StillTheme.calm)
            Text(activity.name)
                .font(StillTypography.title3)
                .foregroundStyle(StillTheme.textPrimary)
            Text(activity.summary)
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textSecondary)
            Text("About \(activity.estimatedMinutes) min")
                .font(StillTypography.caption.weight(.semibold))
                .foregroundStyle(StillTheme.calm)
        }
        .frame(width: 230, alignment: .leading)
        .padding(StillTheme.Spacing.m)
        .background(StillTheme.surface, in: RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous))
    }
}

private struct ShelfFilter: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(StillTypography.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(StillTypography.caption.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? StillTheme.textPrimary : StillTheme.textSecondary)
            .padding(.horizontal, StillTheme.Spacing.s)
            .frame(minHeight: StillTheme.minimumTapSize)
            .background(isSelected ? StillTheme.accentSoft.opacity(0.62) : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(StillRowButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Break shelf") {
    BreakTab()
        .environment(PreviewSupport.appState(populated: true))
}
