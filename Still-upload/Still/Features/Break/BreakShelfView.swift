import SwiftUI

/// A finite shelf of small alternatives. It is organized as two calm activity
/// lists rather than a feed of independently floating recommendation cards.
struct BreakShelfView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCategory: ActivityCategory?

    private var visibleActivities: [BreakActivity] {
        let ranked = BreakShelfRanking().ranked(
            catalog: ActivityCatalog.launchShelf,
            usages: appState.usages,
            personalization: appState.personalization
        )
        return selectedCategory.map { category in ranked.filter { $0.category == category } } ?? ranked
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
                        categoryControls
                        activityGroup(title: "Picked for you", activities: pickedActivities, tint: StillTheme.calmSoft)
                        if !remainingActivities.isEmpty {
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
                .onAppear {
                    #if DEBUG
                    if DemoLaunch.shouldScrollToBottom("break") {
                        DispatchQueue.main.async { proxy.scrollTo("break-bottom", anchor: .bottom) }
                    }
                    #endif
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            Text(Copy.BreakShelf.eyebrow)
                .font(StillTypography.caption)
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(StillTheme.textTertiary)
            Text(Copy.BreakShelf.title)
                .font(StillTypography.display)
                .foregroundStyle(StillTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var categoryControls: some View {
        GlassControlGroup(padding: StillTheme.Spacing.xs, radius: StillTheme.Radius.medium) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StillTheme.Spacing.xs) {
                    ShelfFilter(title: Copy.BreakShelf.all, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(ActivityCategory.allCases, id: \.self) { category in
                        ShelfFilter(title: category.displayName, isSelected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
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
                            .buttonStyle(.plain)
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
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Break shelf") {
    BreakTab()
        .environment(PreviewSupport.appState(populated: true))
}
