import SwiftUI

/// "Is this helping me?" Stats first, then scenes, settings, the Focus Card,
/// honest blocking status, privacy, and local data controls.
struct MeView: View {
    @Environment(AppState.self) private var appState
    @State private var isConfirmingReset = false

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Me")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Is this helping?")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    StatsSection(stats: appState.stats)
                    BreakUsageSection(stats: appState.stats)
                    scenesSection
                    focusSection
                    dailySection
                    AppearanceSection()
                    SoundDefaultsSection()
                    cardAndBlockingSection
                    privacySection
                    #if DEBUG
                    EventLogSection()
                    #endif
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Reset all local data?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                appState.resetAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sessions, tasks, notes, journal lines, habits, doodles, imported books, and settings will be deleted from this device. This can't be undone.")
        }
    }

    private var scenesSection: some View {
        let unlocked = SceneCatalog.all.filter { appState.isUnlocked($0) }.count
        return VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Scenes", detail: nextUnlockLine)
            Button {
                appState.router.go(to: .sceneCollection)
            } label: {
                SettingRow(symbol: "square.grid.2x2", title: "Scene collection", value: "\(unlocked) of \(SceneCatalog.all.count) open")
            }
            .buttonStyle(.plain)
        }
    }

    private var nextUnlockLine: String {
        guard let next = appState.nextLockedScene else { return "Every scene is open." }
        return "\(next.scene.name) opens after \(next.remaining) more completed \(next.remaining == 1 ? "session" : "sessions")."
    }

    private var focusSection: some View {
        let preset = appState.currentPreset
        return VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Focus settings")
            Button {
                appState.router.go(to: .focusConfiguration)
            } label: {
                SettingRow(symbol: "timer", title: "Focus defaults", value: "\(preset.name) · \(DurationSummaryText.short(preset.timer))")
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .presets)
            } label: {
                SettingRow(symbol: "square.stack", title: "Presets", value: "\(appState.presets.count)")
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .tasks)
            } label: {
                SettingRow(symbol: "checklist", title: "Today's tasks", value: "\(appState.todaysTasks.filter { !$0.isCompleted }.count) open")
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .dayTimeline)
            } label: {
                SettingRow(symbol: "calendar.day.timeline.left", title: "Day timeline")
            }
            .buttonStyle(.plain)
        }
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Your days")
            Button {
                appState.router.go(to: .morningStart)
            } label: {
                SettingRow(symbol: "sunrise", title: "Morning Start",
                           value: appState.preferences.morningStart.isEnabled ? appState.preferences.morningStart.summary : "Off")
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .doodleGallery)
            } label: {
                SettingRow(symbol: "paintbrush.pointed", title: "Doodles", value: appState.doodles.isEmpty ? "None yet" : "\(appState.doodles.count) saved")
            }
            .buttonStyle(.plain)
            if !appState.container.flags.journalTab {
                Button {
                    appState.router.go(to: .habits)
                } label: {
                    SettingRow(symbol: "checkmark.circle", title: "Small habits", value: "\(appState.habitDays.count)")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardAndBlockingSection: some View {
        let blocking = appState.container.blocking
        return VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Focus Card")
            Button {
                appState.router.go(to: .nfcSetup)
            } label: {
                SettingRow(symbol: "wave.3.right", title: "Set up a Focus Card", value: "NFC")
            }
            .buttonStyle(.plain)
            if appState.container.flags.appBlocking {
                Button {
                    appState.router.go(to: .blockingSetup)
                } label: {
                    SettingRow(symbol: "shield", title: "Choose apps to block")
                }
                .buttonStyle(.plain)
            }
            StillCard {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                    Text(BlockingCopy.title(for: blocking.capability, isShielding: blocking.isShielding))
                        .font(StillTypography.bodyEmphasis)
                        .foregroundStyle(StillTheme.textPrimary)
                    Text(BlockingCopy.detail(for: blocking.capability))
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Privacy")
            QuietNote(text: "Data stays on this device in this version. No account, no sync, no tracking.", symbol: "lock")
            Button {
                appState.replayOnboarding()
            } label: {
                SettingRow(symbol: "arrow.counterclockwise", title: "Replay onboarding", showsChevron: false)
            }
            .buttonStyle(.plain)
            Button {
                isConfirmingReset = true
            } label: {
                HStack(spacing: StillTheme.Spacing.s) {
                    Image(systemName: "trash")
                        .frame(width: 26)
                        .accessibilityHidden(true)
                    Text("Reset local data")
                    Spacer()
                }
                .font(StillTypography.body)
                .foregroundStyle(StillTheme.attention)
                .frame(minHeight: StillTheme.minimumTapSize)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Asks before deleting everything on this device.")
        }
    }
}

enum DurationSummaryText {
    static func short(_ timer: TimerConfiguration) -> String {
        switch timer.mode {
        case .countUp: return "Count up"
        case .countdown: return DurationFormatter.short(timer.focusDuration)
        case .pomodoro: return "\(timer.focusBlockCount) × \(DurationFormatter.short(timer.focusDuration))"
        }
    }
}

// MARK: - Stats

private struct StatsSection: View {
    let stats: FocusStats

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Your focus")
            if stats.hasHistory {
                StillCard {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                        Text(StatsCalculator.streakLine(current: stats.currentStreak))
                            .font(StillTypography.bodyEmphasis)
                            .foregroundStyle(StillTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        SevenDayFocusView(days: stats.lastSevenDays)
                        Grid(alignment: .leading, horizontalSpacing: StillTheme.Spacing.m, verticalSpacing: StillTheme.Spacing.m) {
                            GridRow {
                                SubtleMetric(value: "\(stats.completedSessions)", label: "Completed sessions")
                                SubtleMetric(value: DurationFormatter.short(stats.totalFocus), label: "Total focus")
                            }
                            GridRow {
                                SubtleMetric(value: DurationFormatter.short(stats.todayFocus), label: "Today")
                                SubtleMetric(value: DurationFormatter.short(stats.weekFocus), label: "Last 7 days")
                            }
                            GridRow {
                                SubtleMetric(value: DurationFormatter.short(stats.averageSessionDuration), label: "Average session")
                                SubtleMetric(value: "\(stats.longestStreak) \(stats.longestStreak == 1 ? "day" : "days")", label: "Longest run of focus days")
                            }
                        }
                    }
                }
                Text("A focus day is any day with at least one completed session.")
                    .font(StillTypography.caption)
                    .foregroundStyle(StillTheme.textTertiary)
            } else {
                StillCard {
                    EmptyState(symbol: "leaf", title: "Nothing here yet", message: "Finish a session and your focus time will show up here. It's all kept on this device.")
                }
            }
        }
    }
}

private struct BreakUsageSection: View {
    let stats: FocusStats

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Breaks", detail: stats.activitiesCompleted == 0 ? "Activities you finish will be counted here." : "\(stats.activitiesCompleted) finished so far.")
            if !stats.activityUsage.isEmpty {
                StillCard {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        ForEach(stats.activityUsage.prefix(4)) { usage in
                            HStack {
                                Text(ActivityCatalog.activity(usage.activityID)?.name ?? "Activity")
                                    .font(StillTypography.callout)
                                    .foregroundStyle(StillTheme.textPrimary)
                                Spacer()
                                Text("\(usage.completedCount) of \(usage.openedCount) finished")
                                    .font(StillTypography.footnote.monospacedDigit())
                                    .foregroundStyle(StillTheme.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}

/// Seven quiet bars, no axes: a glance, not a dashboard.
struct SevenDayFocusView: View {
    let days: [DayFocus]

    var body: some View {
        let maximum = max(days.map(\.focusDuration).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: StillTheme.Spacing.xs) {
            ForEach(days) { day in
                VStack(spacing: StillTheme.Spacing.xxs) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(day.focusDuration > 0 ? StillTheme.accent : StillTheme.border)
                        .frame(height: max(6, 64 * day.focusDuration / maximum))
                    Text(day.day.formatted(.dateTime.weekday(.narrow)))
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.day.formatted(.dateTime.weekday(.wide)))
                .accessibilityValue(day.focusDuration > 0 ? DurationFormatter.short(day.focusDuration) : "No focus")
            }
        }
        .frame(height: 88, alignment: .bottom)
    }
}

// MARK: - Appearance & sound

private struct AppearanceSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let preset = appState.currentPreset
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Appearance", detail: "Motion also turns off when Reduce Motion is on.")
            SelectionPill(
                options: RenderMode.allCases,
                selection: Binding(get: { preset.renderMode }, set: { mode in
                    var edited = preset
                    edited.renderMode = mode
                    appState.savePreset(edited)
                }),
                title: { $0.displayName }
            )
            SelectionPill(
                options: AnimationIntensity.allCases,
                selection: Binding(get: { appState.animationIntensity }, set: { appState.setAnimationIntensity($0) }),
                title: { "\($0.displayName) motion" }
            )
        }
    }
}

private struct SoundDefaultsSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let preset = appState.currentPreset
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Ambient sound", detail: "The default mix for \(preset.name).")
            AmbientMixEditor(
                mix: Binding(get: { preset.ambientMix }, set: { mix in
                    var edited = preset
                    edited.ambientMix = mix
                    appState.savePreset(edited)
                }),
                status: appState.audioStatus,
                isAvailable: { appState.container.audio.isAssetAvailable($0) }
            )
        }
    }
}

#if DEBUG
/// Development-only view of the local event log. Nothing is transmitted.
private struct EventLogSection: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup("Local event log (debug)", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                ForEach(Array(appState.container.events.recentEvents.suffix(25).reversed())) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.name.rawValue)
                            .font(StillTypography.footnote.monospaced())
                        Text(event.properties.values.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " "))
                            .font(StillTypography.caption.monospaced())
                            .foregroundStyle(StillTheme.textTertiary)
                    }
                }
            }
            .padding(.top, StillTheme.Spacing.xs)
        }
        .font(StillTypography.callout)
        .tint(StillTheme.textSecondary)
    }
}
#endif

#Preview("Me · empty") {
    MeTab()
        .environment(PreviewSupport.appState())
}

#Preview("Me · with history") {
    MeTab()
        .environment(PreviewSupport.appState(populated: true))
}
