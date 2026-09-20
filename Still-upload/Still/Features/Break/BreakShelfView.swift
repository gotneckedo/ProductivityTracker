import SwiftUI

/// A finite shelf, not a feed. It ends, and says so.
struct BreakShelfView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Break")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Something finite to do instead. Each one ends.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    ForEach(ActivityCatalog.grouped(), id: \.category) { group in
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            SectionHeader(title: group.category.displayName)
                            ForEach(group.activities) { activity in
                                Button {
                                    appState.router.go(to: .breakActivity(activity.id, .shelf))
                                } label: {
                                    ActivityTile(activity: activity, isDoneToday: appState.usedToday(activity.id))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("That's the whole shelf.")
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, StillTheme.Spacing.s)
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Break shelf") {
    BreakTab()
        .environment(PreviewSupport.appState(populated: true))
}
