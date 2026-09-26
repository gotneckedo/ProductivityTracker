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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                        greeting
                        nextAction
                        afterSection
                        dayContext
                        reflectionCard
                        roomMoment
                        Color.clear.frame(height: 1).id("today-bottom")
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                }
                .stillScrollableViewport()
                .onAppear {
                    #if DEBUG
                    guard DemoLaunch.shouldScrollToBottom("today") else { return }
                    DispatchQueue.main.async { proxy.scrollTo("today-bottom", anchor: .bottom) }
                    #endif
                }
            }
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
                GlassControlGroup {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
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
                        nextActionChoices
                    }
                }
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
                    nextActionChoices
                }
                .modifier(NextActionSurface())
            }
        }
    }

    private var nextActionChoices: some View {
        HStack(spacing: StillTheme.Spacing.s) {
            Button("I don't know what to do") { appState.router.go(to: .nextStep) }
                .buttonStyle(QuietSecondaryButtonStyle())
            Button("Customize") { appState.router.go(to: .focusConfiguration) }
                .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var afterSection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Afterward")
            MatteActivityCanvas(tint: StillTheme.warmSoft) {
                VStack(spacing: 0) {
                    ForEach(Array(afterIDs.enumerated()), id: \.element) { index, id in
                        if let activity = ActivityCatalog.activity(id) {
                            Button {
                                appState.router.go(to: .breakActivity(id, .shelf))
                            } label: {
                                ActivityTile(activity: activity, style: .suggestion)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(activity.name), about \(activity.estimatedMinutes) minutes")
                            if index < afterIDs.count - 1 {
                                InsetRowDivider(leading: 58)
                            }
                        }
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.s)
                .padding(.vertical, StillTheme.Spacing.xs)
            }
        }
    }

    private var dayContext: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Your day")
            HStack(spacing: StillTheme.Spacing.s) {
                contextMetric("Focus today", DurationFormatter.short(appState.stats.todayFocus))
                contextMetric("Usual", usualFocusLabel)
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
                .frame(minHeight: 72, alignment: .topLeading)
            InsetRowDivider()
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
        .modifier(NextActionSurface())
    }

    private var roomMoment: some View {
        Button { appState.router.go(to: .sceneCollection) } label: {
            RoomHeroView(sceneName: appState.currentPreset.sceneID.rawValue, sceneID: appState.currentPreset.sceneID,
                         catCoat: appState.preferences.catCoat,
                         catName: appState.catName,
                         catState: CatCompanion.state(hour: Calendar.autoupdatingCurrent.component(.hour, from: appState.container.clock.now)),
                         allowsCatInteraction: false,
                         showsControls: false,
                         plantStage: appState.plantStage, bookCount: appState.books.count)
                .frame(maxWidth: .infinity)
                .aspectRatio(RoomHeroView.artworkAspectRatio, contentMode: .fit)
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

    private var usualFocusLabel: String {
        guard let usual = appState.stats.usualDailyFocus, usual > 0 else { return "Learning" }
        return DurationFormatter.short(usual)
    }

    private func contextMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(StillTypography.title3).foregroundStyle(StillTheme.textPrimary)
            Text(label).font(StillTypography.caption).foregroundStyle(StillTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }
}

private struct NextActionSurface: ViewModifier {
    func body(content: Content) -> some View {
        GlassControlGroup {
            content
        }
    }
}

#Preview("Today") {
    TodayView().environment(PreviewSupport.appState(populated: true))
}
