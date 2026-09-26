import SwiftUI

/// Still's home is an answer, not a dashboard: one next action, a fast start,
/// and a small amount of context that helps someone leave the app again.
struct TodayView: View {
    @Environment(AppState.self) private var appState
    @State private var reflection = ""
    @State private var mood: JournalMood? = nil

    private var nextTask: TaskItem? {
        appState.selectedTask ?? appState.todaysTasks.first(where: { !$0.isCompleted })
    }

    private var afterIDs: [BreakActivityID] { [.sudoku, .boxBreathing, .shortRead] }

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    greeting
                    nextAction
                    quickChoices
                    afterSection
                    dayContext
                    reflectionCard
                    roomMoment
                    Color.clear.frame(height: 1)
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
            .stillScrollableViewport()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            reflection = appState.journalToday?.text ?? ""
            mood = appState.journalToday?.mood
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            Text("TODAY")
                .font(StillTypography.caption)
                .tracking(1.4)
                .foregroundStyle(StillTheme.textTertiary)
            Text(greetingCopy)
                .font(StillTypography.display)
                .foregroundStyle(StillTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Pick one finite thing. Still can wait when you are done.")
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
        }
    }

    private var nextAction: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            Text("NEXT UP")
                .font(StillTypography.caption)
                .tracking(1.2)
                .foregroundStyle(StillTheme.textTertiary)
            if let task = nextTask {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            if let subject = task.subject {
                                Text(subject.name.uppercased())
                                    .font(StillTypography.caption)
                                    .foregroundStyle(Color(hex: subject.color.hex))
                            }
                            Text(task.title)
                                .font(StillTypography.title)
                                .foregroundStyle(StillTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Text(durationText(task.plannedDuration))
                            .font(StillTypography.bodyEmphasis.monospacedDigit())
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                    Button("Start next task") {
                        appState.selectTask(task.id)
                        appState.startFocus(source: .manual)
                    }
                    .buttonStyle(QuietPrimaryButtonStyle())
                }
                .padding(StillTheme.Spacing.m)
                .stillGlass(radius: StillTheme.Radius.large)
            } else {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                    Text("Nothing is asking for your attention yet.")
                        .font(StillTypography.title3)
                        .foregroundStyle(StillTheme.textPrimary)
                    Text("A small focus round can make room for the next thing.")
                        .font(StillTypography.callout)
                        .foregroundStyle(StillTheme.textSecondary)
                    Button("Start a 25 min focus") { appState.startFocus(source: .manual) }
                        .buttonStyle(QuietPrimaryButtonStyle())
                }
                .padding(StillTheme.Spacing.m)
                .stillGlass(radius: StillTheme.Radius.large)
            }
        }
    }

    private var quickChoices: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            Button("Just Start · 25 min") { appState.startFocus(source: .manual) }
                .buttonStyle(QuietPrimaryButtonStyle())
            HStack(spacing: StillTheme.Spacing.s) {
                Button("I don't know what to do") { appState.router.go(to: .nextStep) }
                    .buttonStyle(QuietSecondaryButtonStyle())
                Button("Customize") { appState.router.go(to: .focusConfiguration) }
                    .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
            }
        }
    }

    private var afterSection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Afterward", detail: "A finite reset for when the timer ends.")
            HStack(spacing: StillTheme.Spacing.s) {
                ForEach(afterIDs, id: \.self) { id in
                    if let activity = ActivityCatalog.activity(id) {
                        Button {
                            appState.router.go(to: .breakActivity(id, .shelf))
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Image(systemName: activity.symbolName)
                                    .foregroundStyle(StillTheme.accent)
                                Text(activity.name)
                                    .font(StillTypography.caption.weight(.semibold))
                                    .foregroundStyle(StillTheme.textPrimary)
                                    .lineLimit(1)
                                Text("\(activity.estimatedMinutes) min")
                                    .font(StillTypography.caption)
                                    .foregroundStyle(StillTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                            .padding(StillTheme.Spacing.s)
                            .stillGlass(radius: StillTheme.Radius.medium)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(activity.name), about \(activity.estimatedMinutes) minutes")
                    }
                }
            }
        }
    }

    private var dayContext: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Your day", detail: "A little context, not a score.")
            HStack(spacing: StillTheme.Spacing.s) {
                contextMetric("Focus today", DurationFormatter.short(appState.stats.todayFocusDuration))
                contextMetric("Usual", DurationFormatter.short(appState.stats.usualDailyFocusDuration))
                contextMetric("Open", "\(appState.todaysTasks.filter { !$0.isCompleted }.count) task\(appState.todaysTasks.filter { !$0.isCompleted }.count == 1 ? "" : "s")")
            }
            Button("See your day") { appState.router.go(to: .dayTimeline) }
                .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
        }
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "A line for today", detail: "For clearing your head, not building a streak.")
            TextField("What is on your mind?", text: $reflection, axis: .vertical)
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textPrimary)
                .lineLimit(2...4)
                .padding(StillTheme.Spacing.s)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
            HStack {
                ForEach(JournalMood.allCases, id: \.self) { option in
                    Button {
                        mood = mood == option ? nil : option
                    } label: {
                        Image(systemName: option.symbolName)
                            .frame(width: 30, height: 30)
                            .background(mood == option ? StillTheme.accent.opacity(0.28) : .clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.displayName)
                    .accessibilityAddTraits(mood == option ? .isSelected : [])
                }
                Spacer()
                Button("Save") { appState.saveJournal(text: reflection, mood: mood) }
                    .buttonStyle(QuietSecondaryButtonStyle())
            }
        }
        .padding(StillTheme.Spacing.m)
        .stillGlass()
    }

    private var roomMoment: some View {
        Button { appState.router.go(to: .sceneCollection) } label: {
            RoomHeroView(sceneName: appState.currentPreset.sceneID.rawValue, sceneID: appState.currentPreset.sceneID,
                         catCoat: appState.preferences.catCoat, plantStage: appState.plantStage, bookCount: appState.books.count)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.65, contentMode: .fit)
                .accessibilityLabel("Your focus room. Opens rooms.")
        }
        .buttonStyle(.plain)
    }

    private var greetingCopy: String {
        let hour = Calendar.current.component(.hour, from: appState.container.clock.now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func durationText(_ duration: TimeInterval?) -> String {
        guard let duration else { return "25 min" }
        return "\(max(1, Int((duration / 60).rounded()))) min"
    }

    private func contextMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(StillTypography.title3).foregroundStyle(StillTheme.textPrimary)
            Text(label).font(StillTypography.caption).foregroundStyle(StillTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(StillTheme.Spacing.s)
        .stillGlass(radius: StillTheme.Radius.medium)
    }
}

#Preview("Today") {
    TodayView().environment(PreviewSupport.appState(populated: true))
}
