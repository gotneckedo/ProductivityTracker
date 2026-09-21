import SwiftUI
import UIKit

/// Onboarding until answered, then the tab app. Modal presentation for the
/// whole app is decided here from router state, never in leaf views.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.preferences.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .overlay(alignment: .top) {
            NoticeBanner()
        }
        .tint(StillTheme.accent)
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let router = appState.router
        ZStack {
            tabContent(router.selectedTab)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if appState.activeSession == nil {
                FloatingTabBar(tabs: router.visibleTabs, selection: Binding(
                    get: { router.selectedTab },
                    set: { router.selectedTab = $0 }
                ))
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.top, StillTheme.Spacing.xs)
                .padding(.bottom, StillTheme.Spacing.xs)
            }
        }
        .sheet(item: Binding(get: { router.sheet }, set: { router.sheet = $0 })) { sheet in
            Group {
                switch sheet {
                case .focusConfiguration:
                    SessionOptionsView()
                case .tasks:
                    TasksSheet()
                case .dayTimeline:
                    NavigationStack {
                        DayTimelineView()
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .environment(appState)
        }
        .fullScreenCover(item: Binding(get: { router.completion }, set: { router.completion = $0 })) { presentation in
            SessionCompleteView(sessionID: presentation.sessionID)
                .environment(appState)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .focus:
            FocusTab()
        case .breakShelf:
            BreakTab()
        case .me:
            MeTab()
        case .journal:
            JournalTab()
        }
    }
}

private struct FloatingTabBar: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = selection == tab
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(StillTypography.callout.weight(.semibold))
                        Text(tab.title)
                            .font(StillTypography.caption)
                    }
                    .foregroundStyle(isSelected ? StillTheme.textPrimary : StillTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(isSelected ? Color.white.opacity(0.54) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(5)
        .stillGlass(radius: 26)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
}

struct FocusTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let router = appState.router
        NavigationStack(path: Binding(get: { router.focusPath }, set: { router.focusPath = $0 })) {
            Group {
                if appState.activeSession != nil {
                    ActiveFocusView()
                } else {
                    FocusHomeView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                RouteView(route: route)
            }
        }
    }
}

struct BreakTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let router = appState.router
        NavigationStack(path: Binding(get: { router.breakPath }, set: { router.breakPath = $0 })) {
            BreakShelfView()
                .navigationDestination(for: AppRoute.self) { route in
                    RouteView(route: route)
                }
        }
    }
}

struct JournalTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let router = appState.router
        NavigationStack(path: Binding(get: { router.journalPath }, set: { router.journalPath = $0 })) {
            JournalView()
                .navigationDestination(for: AppRoute.self) { route in
                    RouteView(route: route)
                }
        }
    }
}

struct MeTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let router = appState.router
        NavigationStack(path: Binding(get: { router.mePath }, set: { router.mePath = $0 })) {
            MeView()
                .navigationDestination(for: AppRoute.self) { route in
                    RouteView(route: route)
                }
        }
    }
}

/// Maps pushed routes to screens.
struct RouteView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .breakActivity(let id, let context):
            ActivityContainerView(activityID: id, context: context)
        case .nfcSetup:
            FocusCardView()
        case .sceneCollection:
            SceneCollectionView()
        case .roomCollection:
            RoomCollectionView()
        case .presets:
            PresetsView()
        case .doodleGallery:
            DoodleGalleryView()
        case .morningStart:
            MorningStartView()
        case .blockingSetup:
            BlockingSetupView()
        case .habits:
            HabitsScreen()
        case .focusHome, .focusConfiguration, .activeSession, .sessionComplete, .breakShelf, .tasks, .me, .journal, .dayTimeline:
            // These are tab roots or modals, never pushed.
            EmptyView()
        }
    }
}

/// Habits on their own screen, for when the Journal tab is off.
struct HabitsScreen: View {
    var body: some View {
        StillScreen {
            ScrollView {
                HabitsSection()
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

/// A calm, self-dismissing message. Tap to dismiss early.
struct NoticeBanner: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let notice = appState.notice {
            Text(notice.text)
                .font(StillTypography.footnote.weight(.medium))
                .foregroundStyle(StillTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, StillTheme.Spacing.m)
                .padding(.vertical, StillTheme.Spacing.s)
                .background(Capsule(style: .continuous).fill(StillTheme.surface))
                .overlay(Capsule(style: .continuous).strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline))
                .shadow(color: StillTheme.Shadow.color, radius: StillTheme.Shadow.radius, y: StillTheme.Shadow.y)
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.top, StillTheme.Spacing.xs)
                .transition(.opacity)
                .onTapGesture { appState.notice = nil }
                .onAppear {
                    UIAccessibility.post(notification: .announcement, argument: notice.text)
                }
                .task(id: notice.id) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    if appState.notice?.id == notice.id {
                        appState.notice = nil
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Dismisses this message.")
        }
    }
}
