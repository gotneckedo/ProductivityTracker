import SwiftUI

/// DEBUG review surface for the visual previews used by long-press menus.
/// It is intentionally not linked from the customer interface; normal people
/// discover these treatments by holding their target, not by opening a guide.
struct ContextPreviewReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var scrolledToProofBottom = false

    private let columns = [
        GridItem(.flexible(), spacing: StillTheme.Spacing.s),
        GridItem(.flexible(), spacing: StillTheme.Spacing.s)
    ]

    private var roomSnapshot: RoomSecondLayerSnapshot {
        let phase = StillDayPhase.automatic(date: appState.container.clock.now, colorScheme: colorScheme)
        return RoomSecondLayerSnapshot(
            selectedTaskTitle: appState.selectedTask?.title,
            books: appState.books.map(\.title),
            plantStage: appState.plantStage,
            windowPhaseName: phase.rawValue,
            totalFocus: appState.stats.totalFocus,
            weeklyFocus: appState.stats.lastSevenDays.map {
                RoomSecondLayerDay(day: $0.day, focusDuration: $0.focusDuration)
            },
            now: appState.container.clock.now,
            calendar: appState.container.calendar
        )
    }

    private var shouldCaptureProofBottom: Bool {
        #if DEBUG || STILL_PROOF
        DemoLaunch.shouldScrollToBottom("context-previews")
        #else
        false
        #endif
    }

    var body: some View {
        StillScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                            Text("Room long-press previews")
                                .font(StillTypography.display)
                                .foregroundStyle(StillTheme.textPrimary)
                            Text("Review-only: these are the same local facts shown when an object in the Focus room is held.")
                                .font(StillTypography.footnote)
                                .foregroundStyle(StillTheme.textSecondary)
                        }

                        LazyVGrid(columns: columns, spacing: StillTheme.Spacing.s) {
                            ForEach(RoomSecondLayerTarget.allCases) { target in
                                RoomSecondLayerReviewTile(fact: roomSnapshot.fact(for: target))
                            }
                        }
                        Color.clear.frame(height: 1).id("roomSecondLayerProofEnd")
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                }
                .stillScrollableViewport()
                .onAppear {
                    guard shouldCaptureProofBottom, !scrolledToProofBottom else { return }
                    scrolledToProofBottom = true
                    DispatchQueue.main.async {
                        proxy.scrollTo("roomSecondLayerProofEnd", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("Interaction previews")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct RoomSecondLayerReviewTile: View {
    let fact: RoomSecondLayerFact

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            HStack(spacing: StillTheme.Spacing.xs) {
                Image(systemName: fact.symbolName)
                    .font(StillTypography.callout.weight(.semibold))
                    .foregroundStyle(StillTheme.accent)
                    .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                    .background(StillTheme.accentSoft, in: Circle())
                Text(fact.title)
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                    .lineLimit(1)
            }
            Text(fact.detail)
                .font(StillTypography.caption.weight(.semibold))
                .foregroundStyle(StillTheme.textPrimary)
                .lineLimit(2)
            Text(fact.supportingDetail)
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .padding(StillTheme.Spacing.s)
        .stillGlass(radius: StillTheme.Radius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(fact.accessibilityDescription)
    }
}
