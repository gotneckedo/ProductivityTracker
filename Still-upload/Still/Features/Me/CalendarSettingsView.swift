import SwiftUI

struct CalendarSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Calendar settings")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Put class times and study plans beside your tasks. Still only reads events; it never changes them.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    calendarCard(
                        symbol: "calendar",
                        title: "Apple Calendar",
                        detail: "Works now with calendars on this iPhone, including Google accounts added in iOS Settings.",
                        status: appleStatus,
                        actionTitle: appleActionTitle,
                        action: appleAction
                    )

                    StillCard {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            HStack(alignment: .top) {
                                Image(systemName: "g.circle")
                                    .font(StillTypography.title3)
                                    .foregroundStyle(StillTheme.textPrimary)
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                                    Text("Google Calendar")
                                        .font(StillTypography.bodyEmphasis)
                                    Text("Direct Google sign-in is represented with two sample events. No Google account is contacted in this preview.")
                                        .font(StillTypography.footnote)
                                        .foregroundStyle(StillTheme.textSecondary)
                                }
                                Spacer()
                                if appState.container.googleCalendar.isStandIn { PreviewTag() }
                            }
                            Text(googleStatus)
                                .font(StillTypography.footnote)
                                .foregroundStyle(StillTheme.textSecondary)
                            if appState.showsGoogleCalendarEvents {
                                Button("Hide sample events") { appState.setShowsGoogleCalendarEvents(false) }
                                    .buttonStyle(QuietSecondaryButtonStyle())
                            } else {
                                Button("Show sample events") { appState.connectGoogleCalendar() }
                                    .buttonStyle(QuietSecondaryButtonStyle())
                            }
                        }
                    }

                    QuietNote(
                        text: "A real direct Google connection needs OAuth credentials, a public privacy policy, and Google's review. Until then, adding Google to iOS Settings is the working route.",
                        symbol: "lock"
                    )
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var appleStatus: String {
        switch appState.calendarAccess {
        case .granted: return appState.preferences.showsCalendarEvents ? "Shown on the day timeline" : "Connected · hidden"
        case .denied: return "Access is off in iOS Settings"
        case .notDetermined: return "Not connected"
        case .unavailable: return "Unavailable on this device"
        }
    }

    private var appleActionTitle: String {
        appState.preferences.showsCalendarEvents ? "Hide Apple events" : "Connect or show events"
    }

    private var appleAction: () -> Void {
        { appState.setShowsCalendarEvents(!appState.preferences.showsCalendarEvents) }
    }

    private var googleStatus: String {
        appState.showsGoogleCalendarEvents ? "Showing sample events on the day timeline" : "Sample events are hidden"
    }

    private func calendarCard(symbol: String, title: String, detail: String, status: String,
                              actionTitle: String, action: @escaping () -> Void) -> some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
                    Image(systemName: symbol)
                        .font(StillTypography.title3)
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text(title).font(StillTypography.bodyEmphasis)
                        Text(detail)
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                }
                Text(status)
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                Button(actionTitle, action: action)
                    .buttonStyle(QuietSecondaryButtonStyle())
            }
        }
    }
}

#Preview("Calendar settings") {
    NavigationStack { CalendarSettingsView() }
        .environment(PreviewSupport.appState())
}
