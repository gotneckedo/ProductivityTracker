import SwiftUI

/// A finite shelf of small alternatives, deliberately never an infinite feed.
/// The two lead choices answer "what now?" while the rest remain visible at a
/// glance—without becoming a recommendation stream.
struct BreakShelfView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCategory: ActivityCategory?

    private var visibleActivities: [BreakActivity] {
        let ranked = BreakShelfRanking().ranked(
            catalog: ActivityCatalog.available,
            usages: appState.usages,
            personalization: appState.personalization
        )
        return selectedCategory.map { category in ranked.filter { $0.category == category } } ?? ranked
    }

    private var pickedActivities: [BreakActivity] {
        Array(visibleActivities.prefix(2))
    }

    private var gridActivities: [BreakActivity] {
        Array(visibleActivities.dropFirst(pickedActivities.count))
    }

    var body: some View {
        StillScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    header
                    categoryChips
                    pickedSection
                    activityGrid
                    Color.clear.frame(height: 1).id("break-midpoint")
                    recentSection
                    Text(Copy.BreakShelf.wholeShelf)
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, StillTheme.Spacing.s)
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
                    } else if DemoLaunch.shouldScrollToMidpoint("break") {
                        DispatchQueue.main.async { proxy.scrollTo("break-midpoint", anchor: .top) }
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
            Text(Copy.BreakShelf.detail)
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StillTheme.Spacing.xs) {
                ShelfFilter(title: Copy.BreakShelf.all, isSelected: selectedCategory == nil) { selectedCategory = nil }
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
    private var pickedSection: some View {
        if !pickedActivities.isEmpty {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                SectionHeader(title: Copy.BreakShelf.pickedForYou,
                              detail: selectedCategory == nil ? "A small, varied reset based on what you chose in Still." : nil)
                ForEach(pickedActivities) { activity in
                    Button {
                        appState.router.go(to: .breakActivity(activity.id, .shelf))
                    } label: {
                        WideShelfTile(activity: activity, status: appState.activityStatus(for: activity.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var activityGrid: some View {
        if !gridActivities.isEmpty {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                if selectedCategory == nil {
                    Text(Copy.BreakShelf.allActivities)
                        .font(StillTypography.title)
                        .foregroundStyle(StillTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: StillTheme.Spacing.s), GridItem(.flexible(), spacing: StillTheme.Spacing.s)],
                    spacing: StillTheme.Spacing.s
                ) {
                    ForEach(gridActivities) { activity in
                        Button {
                            appState.router.go(to: .breakActivity(activity.id, .shelf))
                        } label: {
                            ShelfTile(activity: activity, status: appState.activityStatus(for: activity.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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

private struct WideShelfTile: View {
    let activity: BreakActivity
    let status: ActivityStatus

    private var style: ActivityVisualStyle { ActivityPresentation.visualStyle(for: activity.id) }
    private var glow: Color { Color(hex: style.glowHex) }
    private var accent: Color { Color(hex: style.accentHex) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(glow.opacity(0.62))
                .frame(width: 142, height: 142)
                .blur(radius: 22)
                .offset(x: 35, y: -44)
                .accessibilityHidden(true)
            HStack(alignment: .top, spacing: StillTheme.Spacing.m) {
                Image(systemName: activity.symbolName)
                    .font(StillTypography.title)
                    .foregroundStyle(accent)
                    .frame(width: 50, height: 50)
                    .background(glow.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.name)
                        .font(StillTypography.title3)
                        .foregroundStyle(StillTheme.textPrimary)
                    Text(activity.summary)
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                        .lineLimit(2)
                    ActivityStatusLabel(status: status, accent: accent)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(StillTypography.footnote.weight(.semibold))
                    .foregroundStyle(StillTheme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(StillTheme.Spacing.m)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .stillGlass(radius: StillTheme.Radius.large)
        .contentShape(RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.name), about \(activity.estimatedMinutes) minutes. \(activity.summary). \(status.text)")
    }
}

private struct ShelfTile: View {
    let activity: BreakActivity
    let status: ActivityStatus

    private var style: ActivityVisualStyle { ActivityPresentation.visualStyle(for: activity.id) }
    private var glow: Color { Color(hex: style.glowHex) }
    private var accent: Color { Color(hex: style.accentHex) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(glow.opacity(0.58))
                .frame(width: 100, height: 100)
                .blur(radius: 18)
                .offset(x: 28, y: -31)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                HStack {
                    Image(systemName: activity.symbolName)
                        .font(StillTypography.title3)
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                        .background(glow.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Spacer()
                }
                Text(activity.name)
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("\(activity.estimatedMinutes) min · \(status.text)")
                    .font(StillTypography.caption)
                    .foregroundStyle(StillTheme.textSecondary)
                    .lineLimit(2)
            }
            .padding(StillTheme.Spacing.s)
        }
        .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
        .stillGlass(radius: StillTheme.Radius.medium)
        .contentShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.name), about \(activity.estimatedMinutes) minutes. \(status.text)")
    }
}

private struct ActivityStatusLabel: View {
    let status: ActivityStatus
    let accent: Color

    var body: some View {
        Text(status.text)
            .font(StillTypography.caption.weight(.semibold))
            .foregroundStyle(status.kind == .fresh ? StillTheme.textSecondary : accent)
            .lineLimit(1)
            .padding(.top, 2)
    }
}

#Preview("Break shelf") {
    BreakTab()
        .environment(PreviewSupport.appState(populated: true))
}
