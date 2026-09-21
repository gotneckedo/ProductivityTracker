import SwiftUI

/// A finite shelf of small alternatives, deliberately never an infinite feed.
struct BreakShelfView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCategory: ActivityCategory?

    private var visibleActivities: [BreakActivity] {
        let activities = ActivityCatalog.available
        return selectedCategory.map { category in activities.filter { $0.category == category } } ?? activities
    }

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    header
                    categoryChips
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: StillTheme.Spacing.s), GridItem(.flexible(), spacing: StillTheme.Spacing.s)], spacing: StillTheme.Spacing.s) {
                        ForEach(visibleActivities) { activity in
                            Button {
                                appState.router.go(to: .breakActivity(activity.id, .shelf))
                            } label: {
                                ShelfTile(activity: activity, isDoneToday: appState.usedToday(activity.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    recentSection
                    Text(Copy.BreakShelf.wholeShelf)
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, StillTheme.Spacing.s)
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
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
            Text(Copy.BreakShelf.detail)
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StillTheme.Spacing.xs) {
                ShelfFilter(title: "All", isSelected: selectedCategory == nil) { selectedCategory = nil }
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    ShelfFilter(title: category.displayName, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        let recentIDs = Array(appState.usages.sorted { $0.startedAt > $1.startedAt }.prefix(3).map(\.activityID))
        if !recentIDs.isEmpty {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                Text(Copy.BreakShelf.recent)
                    .font(StillTypography.title3)
                    .foregroundStyle(StillTheme.textPrimary)
                HStack(spacing: StillTheme.Spacing.xs) {
                    ForEach(recentIDs, id: \.self) { id in
                        if let activity = ActivityCatalog.activity(id) {
                            Text(activity.name)
                                .font(StillTypography.caption)
                                .foregroundStyle(StillTheme.textSecondary)
                                .padding(.horizontal, StillTheme.Spacing.s)
                                .frame(minHeight: 34)
                                .background(.white.opacity(0.24), in: Capsule())
                        }
                    }
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
            Text(title)
                .font(StillTypography.caption)
                .foregroundStyle(isSelected ? StillTheme.textPrimary : StillTheme.textSecondary)
                .padding(.horizontal, StillTheme.Spacing.s)
                .frame(minHeight: StillTheme.minimumTapSize)
                .background(isSelected ? .white.opacity(0.46) : .white.opacity(0.16), in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? .white.opacity(0.8) : .white.opacity(0.38), lineWidth: StillTheme.Stroke.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ShelfTile: View {
    let activity: BreakActivity
    let isDoneToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            HStack {
                Image(systemName: activity.symbolName)
                    .font(StillTypography.title3)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer()
                if isDoneToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.accent)
                }
            }
            Text(activity.name)
                .font(StillTypography.bodyEmphasis)
                .foregroundStyle(StillTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text("\(activity.estimatedMinutes) min")
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textSecondary)
        }
        .padding(StillTheme.Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .stillGlass(radius: StillTheme.Radius.medium)
        .contentShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.name), about \(activity.estimatedMinutes) minutes\(isDoneToday ? ", completed today" : "")")
    }

    private var tint: Color {
        switch activity.category {
        case .puzzle: return Color(hex: 0x6E92C8)
        case .quiet: return Color(hex: 0xA77BC2)
        case .reset: return Color(hex: 0xD99163)
        }
    }
}

#Preview("Break shelf") {
    BreakTab()
        .environment(PreviewSupport.appState(populated: true))
}
