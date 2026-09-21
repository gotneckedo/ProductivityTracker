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
                    ProfileHero(stats: appState.stats)

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
                SettingRow(symbol: "square.grid.2x2", title: "Scene collection", value: "\(unlocked) of \(SceneCatalog.all.count) open",
                           iconTint: StillTheme.calm, iconBackground: StillTheme.calmSoft)
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
                SettingRow(symbol: "timer", title: "Focus defaults", value: "\(preset.name) · \(DurationSummaryText.short(preset.timer))",
                           iconTint: StillTheme.accent, iconBackground: StillTheme.accentSoft)
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .presets)
            } label: {
                SettingRow(symbol: "square.stack", title: "Presets", value: "\(appState.presets.count)",
                           iconTint: StillTheme.warm, iconBackground: StillTheme.warmSoft)
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .tasks)
            } label: {
                SettingRow(symbol: "checklist", title: "Today's tasks", value: "\(appState.todaysTasks.filter { !$0.isCompleted }.count) open",
                           iconTint: StillTheme.highlight, iconBackground: StillTheme.highlightSoft)
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .dayTimeline)
            } label: {
                SettingRow(symbol: "calendar.day.timeline.left", title: "Day timeline",
                           iconTint: StillTheme.calm, iconBackground: StillTheme.calmSoft)
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
                           value: appState.preferences.morningStart.isEnabled ? appState.preferences.morningStart.summary : "Off",
                           iconTint: StillTheme.warm, iconBackground: StillTheme.warmSoft)
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .doodleGallery)
            } label: {
                SettingRow(symbol: "paintbrush.pointed", title: "Doodles", value: appState.doodles.isEmpty ? "None yet" : "\(appState.doodles.count) saved",
                           iconTint: StillTheme.attention, iconBackground: StillTheme.attentionSoft)
            }
            .buttonStyle(.plain)
            if !appState.container.flags.journalTab {
                Button {
                    appState.router.go(to: .habits)
                } label: {
                    SettingRow(symbol: "checkmark.circle", title: "Small habits", value: "\(appState.habitDays.count)",
                               iconTint: StillTheme.accent, iconBackground: StillTheme.accentSoft)
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
                SettingRow(symbol: "wave.3.right", title: "Set up a Focus Card", value: "NFC",
                           iconTint: StillTheme.warm, iconBackground: StillTheme.warmSoft)
            }
            .buttonStyle(.plain)
            if appState.container.flags.appBlocking {
                Button {
                    appState.router.go(to: .blockingSetup)
                } label: {
                    SettingRow(symbol: "shield", title: "Blocking and schedule",
                               iconTint: StillTheme.calm, iconBackground: StillTheme.calmSoft)
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
            SectionHeader(title: "Your preferences", detail: "Change one answer without resetting anything else.")
            Button {
                appState.router.go(to: .onboardingGoalPreference)
            } label: {
                SettingRow(symbol: "scope", title: "Focus goal", value: appState.preferences.onboardingGoal?.title ?? "Not set")
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .onboardingBreakPreference)
            } label: {
                SettingRow(symbol: "cup.and.saucer", title: "Break preference", value: appState.preferences.breakAppeal?.title ?? "Not set")
            }
            .buttonStyle(.plain)
            Button {
                appState.router.go(to: .onboardingLookPreference)
            } label: {
                SettingRow(symbol: "paintpalette", title: "Look & app icon", value: appState.preferences.appAccentPalette.title)
            }
            .buttonStyle(.plain)

            SectionHeader(title: "Privacy")
                .padding(.top, StillTheme.Spacing.s)
            QuietNote(text: "Processed on this device. No account. No servers.", symbol: "lock")
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

private struct ProfileHero: View {
    let stats: FocusStats

    var body: some View {
        HStack(spacing: StillTheme.Spacing.m) {
            ZStack {
                Circle().fill(StillTheme.accentSoft)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(StillTheme.accent)
            }
            .frame(width: 66, height: 66)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Me")
                    .font(StillTypography.display)
                    .foregroundStyle(StillTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(stats.hasHistory ? StatsCalculator.streakLine(current: stats.currentStreak) : "A quiet place to notice what helps.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(StillTheme.Spacing.m)
        .stillGlass(radius: StillTheme.Radius.large)
        .accessibilityElement(children: .combine)
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
    @State private var selectedRange: FocusStatsRange = .week

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Your focus")
            if stats.hasHistory {
                StillCard {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                        FocusRangePicker(selection: $selectedRange)
                        if let range = stats.data(for: selectedRange) {
                            FocusRangeHero(data: range)
                            FocusRangeChart(data: range)
                        }
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
                                if let longest = StatsCalculator.streakValue(stats.longestStreak) {
                                    SubtleMetric(value: longest, label: "Longest run of focus days")
                                } else {
                                    SubtleMetric(value: "Starts with one session", label: "Focus rhythm")
                                }
                            }
                        }
                    }
                }
                FocusMonthCalendar(month: stats.calendarMonth)
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

private struct FocusRangePicker: View {
    @Binding var selection: FocusStatsRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FocusStatsRange.allCases, id: \.self) { range in
                Button(range.displayName) { selection = range }
                    .font(StillTypography.caption.weight(.semibold))
                    .foregroundStyle(selection == range ? StillTheme.textPrimary : StillTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: StillTheme.minimumTapSize)
                    .background(selection == range ? Color.white.opacity(0.54) : .clear, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == range ? .isSelected : [])
            }
        }
        .padding(4)
        .background(StillTheme.surfaceSunken, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Statistics range")
    }
}

private struct FocusRangeHero: View {
    let data: FocusRangeData

    var body: some View {
        VStack(spacing: StillTheme.Spacing.xxs) {
            Text(data.range.summaryName)
                .font(StillTypography.caption.weight(.semibold))
                .foregroundStyle(StillTheme.textSecondary)
            Text(DurationFormatter.short(data.focusDuration))
                .font(StillTypography.hero)
                .foregroundStyle(StillTheme.textPrimary)
                .monospacedDigit()
            Text(comparisonLine)
                .font(StillTypography.caption.weight(.semibold))
                .foregroundStyle(StillTheme.accent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StillTheme.Spacing.s)
        .background {
            Circle()
                .fill(RadialGradient(colors: [StillDayPhase.morning.roomHalo.opacity(0.72), .clear], center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 150)
                .blur(radius: 12)
        }
        .accessibilityElement(children: .combine)
    }

    private var comparisonLine: String {
        guard data.usualDailyFocus != nil, let comparison = data.comparisonToUsual else {
            return "Your own usual appears after a few focus days."
        }
        switch comparison {
        case .lighter: return "A lighter stretch than your usual, and that's fine."
        case .aboutUsual: return "About your usual."
        case .more: return "A bit more than your usual."
        }
    }
}

private struct FocusRangeChart: View {
    let data: FocusRangeData

    var body: some View {
        let maximum = max(data.points.map(\.focusDuration).max() ?? 0, data.usualReferenceFocus ?? 0, 1)
        GeometryReader { proxy in
            let plotHeight = max(1, proxy.size.height - 24)
            ZStack(alignment: .bottom) {
                if let usual = data.usualReferenceFocus, usual > 0 {
                    let y = min(plotHeight, plotHeight * usual / maximum)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: plotHeight - y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: plotHeight - y))
                    }
                    .stroke(StillTheme.textTertiary, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    Text("usual")
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(StillTheme.surface, in: Capsule())
                        .position(x: proxy.size.width - 24, y: max(7, plotHeight - y))
                        .accessibilityHidden(true)
                }
                HStack(alignment: .bottom, spacing: data.points.count > 12 ? 2 : StillTheme.Spacing.xs) {
                    ForEach(Array(data.points.enumerated()), id: \.element.id) { index, point in
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isCurrent(point) ? StillTheme.highlight : (point.focusDuration > 0 ? StillTheme.accent.opacity(0.76) : StillTheme.surfaceSunken))
                                .shadow(color: isCurrent(point) ? StillTheme.highlight.opacity(0.58) : .clear, radius: 8)
                                .frame(height: max(6, plotHeight * point.focusDuration / maximum))
                            if shouldLabel(index) {
                                Text(label(for: point.date))
                                    .font(StillTypography.caption)
                                    .foregroundStyle(StillTheme.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityDate(point.date))
                        .accessibilityValue(point.focusDuration > 0 ? DurationFormatter.short(point.focusDuration) : "No focus")
                    }
                }
            }
        }
        .frame(height: 112)
        .accessibilityElement(children: .contain)
    }

    private func isCurrent(_ point: FocusRangePoint) -> Bool {
        switch data.range {
        case .year:
            return Calendar.current.isDate(point.date, equalTo: .now, toGranularity: .month)
        default:
            return Calendar.current.isDateInToday(point.date)
        }
    }

    private func shouldLabel(_ index: Int) -> Bool {
        switch data.range {
        case .day, .week, .year: return true
        case .month: return index == 0 || (index + 1) % 7 == 0 || index == data.points.count - 1
        }
    }

    private func label(for date: Date) -> String {
        switch data.range {
        case .day: return "Today"
        case .week: return date.formatted(.dateTime.weekday(.narrow))
        case .month: return date.formatted(.dateTime.day())
        case .year: return date.formatted(.dateTime.month(.narrow))
        }
    }

    private func accessibilityDate(_ date: Date) -> String {
        data.range == .year
            ? date.formatted(.dateTime.month(.wide).year())
            : date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

private struct FocusMonthCalendar: View {
    let month: FocusCalendarMonth
    private let columns = Array(repeating: GridItem(.flexible(), spacing: StillTheme.Spacing.xs), count: 7)

    var body: some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                Text(month.monthStart.formatted(.dateTime.month(.wide).year()))
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                LazyVGrid(columns: columns, spacing: StillTheme.Spacing.s) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(StillTypography.caption.weight(.semibold))
                            .foregroundStyle(StillTheme.textTertiary)
                    }
                    ForEach(0..<month.leadingWeekdayCount, id: \.self) { _ in
                        Color.clear.frame(height: 38)
                    }
                    ForEach(month.days) { day in
                        CalendarDayIcon(day: day)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let shift = Calendar.current.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}

private struct CalendarDayIcon: View {
    let day: FocusCalendarDay

    var body: some View {
        VStack(spacing: 2) {
            Text(day.date.formatted(.dateTime.day()))
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textSecondary)
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(day.kind == .focused ? StillTheme.accent : StillTheme.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(day.kind == .focused ? StillTheme.accentSoft.opacity(0.58) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(accessibilityValue)
    }

    private var symbol: String {
        switch day.kind {
        case .focused: return "leaf.fill"
        case .quiet: return "circle.fill"
        case .upcoming: return "circle"
        }
    }

    private var accessibilityValue: String {
        switch day.kind {
        case .focused: return DurationFormatter.short(day.focusDuration)
        case .quiet: return "Quiet day"
        case .upcoming: return "Upcoming"
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
