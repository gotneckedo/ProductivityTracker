import SwiftUI

/// Still's home is an answer, not a dashboard: one next action, a fast start,
/// and a small amount of context that helps someone leave the app again.
struct TodayView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var reflection = ""
    @State private var mood: JournalMood? = nil
    @State private var routineItems: [TodayRoutineItem] = []
    @State private var newRoutineTitle = ""
    @State private var didRecheckDay = false

    private var nextTask: TaskItem? {
        appState.selectedTask ?? appState.todaysTasks.first(where: { !$0.isCompleted })
    }

    private var afterIDs: [BreakActivityID] { [.sudoku, .boxBreathing, .shortRead] }

    /// Uses the same injected clock as Today’s greeting, records, and DEBUG
    /// fixtures. This keeps the page phase truthful at runtime and permits a
    /// deterministic morning screenshot without relying on status-bar chrome.
    private var screenPhase: StillDayPhase {
        StillDayPhase.automatic(date: appState.container.clock.now, colorScheme: colorScheme)
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize || DemoLaunch.forcesAccessibilityTextSize
    }

    var body: some View {
        StillScreen(phase: screenPhase) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                        greeting
                        if didRecheckDay {
                            QuietNote(text: "Day checked. Your next small step is still here.", symbol: "arrow.clockwise")
                                .transition(.opacity)
                        }
                        nextAction
                        afterSection
                        dayContext
                        routineSection.id("today-routine")
                        reflectionCard
                        roomMoment
                        Color.clear.frame(height: 1).id("today-bottom")
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                }
                .stillScrollableViewport()
                .refreshable { recheckDay() }
                .onAppear {
                    #if DEBUG
                    if DemoLaunch.requestedScreen == "today-routine" {
                        DispatchQueue.main.async { proxy.scrollTo("today-routine", anchor: .top) }
                    } else if DemoLaunch.shouldScrollToBottom("today") {
                        DispatchQueue.main.async { proxy.scrollTo("today-bottom", anchor: .bottom) }
                    }
                    #endif
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            reflection = appState.journalToday?.text ?? ""
            mood = appState.journalToday?.mood
            routineItems = appState.todayRoutineItems
            #if DEBUG || STILL_PROOF
            didRecheckDay = DemoLaunch.requestedScreen == "today-refreshed"
            #endif
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
                                        .foregroundStyle(Color(hex: subject.color.textHex))
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
                        primaryActionRow(title: "Start next task") {
                            appState.selectTask(task.id)
                            appState.startFocus(source: .manual)
                        }
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
                    primaryActionRow(title: "Start a 25 min focus") {
                        appState.startFocus(source: .manual)
                    }
                    nextActionChoices
                }
                .modifier(NextActionSurface())
            }
        }
    }

    private var nextActionChoices: some View {
        Group {
            if usesAccessibilityLayout {
                EmptyView()
            } else {
                HStack(spacing: StillTheme.Spacing.s) {
                    Button("I don't know what to do") { appState.router.go(to: .nextStep) }
                        .buttonStyle(QuietSecondaryButtonStyle())
                    Button("Customize") { appState.router.go(to: .focusConfiguration) }
                        .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func primaryActionRow(title: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: StillTheme.Spacing.s) {
            if usesAccessibilityLayout {
                Menu {
                    Button("I don't know what to do") { appState.router.go(to: .nextStep) }
                    Button("Customize focus") { appState.router.go(to: .focusConfiguration) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(StillTypography.title3.weight(.semibold))
                        .foregroundStyle(StillTheme.accent)
                        .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                        .background(StillTheme.surfaceSunken, in: Circle())
                }
                .accessibilityLabel("Focus alternatives")
                .accessibilityHint("Includes a next-step guide and focus customization.")
            }
            Button(title, action: action)
                .buttonStyle(QuietPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
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

    private var routineSection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(
                title: "Small routine",
                detail: routineItems.isEmpty ? "Optional prompts for the shape of your day." : "Move, change, or remove any prompt."
            )
            MatteActivityCanvas(tint: StillTheme.accentSoft.opacity(0.72)) {
                VStack(spacing: 0) {
                    ForEach(Array(routineItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: StillTheme.Spacing.s) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(StillTheme.textTertiary)
                                .accessibilityHidden(true)
                            TextField("A small prompt", text: routineBinding(for: item.id))
                                .font(StillTypography.callout)
                                .foregroundStyle(StillTheme.textPrimary)
                                .onSubmit(commitRoutine)
                            Spacer(minLength: 0)
                            Button { moveRoutine(item.id, by: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(StillRowButtonStyle())
                                .disabled(index == 0)
                                .accessibilityLabel("Move \(item.title) earlier")
                            Button { moveRoutine(item.id, by: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(StillRowButtonStyle())
                                .disabled(index == routineItems.count - 1)
                                .accessibilityLabel("Move \(item.title) later")
                            Button { removeRoutine(item.id) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(StillRowButtonStyle())
                                .accessibilityLabel("Remove \(item.title)")
                        }
                        .stillInsetRow(verticalPadding: StillTheme.Spacing.xs)
                        if index < routineItems.count - 1 { InsetRowDivider(leading: 32) }
                    }
                    if canAddRoutine {
                        if !routineItems.isEmpty { InsetRowDivider(leading: 32) }
                        HStack(spacing: StillTheme.Spacing.s) {
                            Image(systemName: "plus")
                                .foregroundStyle(StillTheme.accent)
                                .frame(width: 18)
                            TextField("Add a prompt", text: $newRoutineTitle)
                                .font(StillTypography.callout)
                                .onSubmit(addRoutine)
                            Button("Add", action: addRoutine)
                                .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
                                .disabled(TodayRoutineItem.normalized(newRoutineTitle) == nil)
                        }
                        .stillInsetRow(verticalPadding: StillTheme.Spacing.xs)
                    } else {
                        InsetRowDivider(leading: 32)
                        Text("Three prompts keep Today quiet in this build.")
                            .font(StillTypography.caption)
                            .foregroundStyle(StillTheme.textSecondary)
                            .stillInsetRow(verticalPadding: StillTheme.Spacing.xs)
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.s)
                .padding(.vertical, StillTheme.Spacing.xs)
            }
        }
    }

    private var canAddRoutine: Bool { appState.canAddTodayRoutineItem }

    private func routineBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { routineItems.first(where: { $0.id == id })?.title ?? "" },
            set: { value in
                guard let index = routineItems.firstIndex(where: { $0.id == id }) else { return }
                routineItems[index].title = String(value.prefix(TodayRoutineItem.maximumTitleLength))
            }
        )
    }

    private func commitRoutine() {
        routineItems = routineItems.compactMap { item in
            guard let title = TodayRoutineItem.normalized(item.title) else { return nil }
            return TodayRoutineItem(id: item.id, title: title)
        }
        appState.setTodayRoutineItems(routineItems)
    }

    private func addRoutine() {
        guard canAddRoutine, let title = TodayRoutineItem.normalized(newRoutineTitle) else { return }
        routineItems.append(TodayRoutineItem(title: title))
        newRoutineTitle = ""
        commitRoutine()
    }

    private func removeRoutine(_ id: UUID) {
        routineItems.removeAll { $0.id == id }
        commitRoutine()
    }

    private func moveRoutine(_ id: UUID, by delta: Int) {
        guard let index = routineItems.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + delta
        guard routineItems.indices.contains(destination) else { return }
        routineItems.swapAt(index, destination)
        commitRoutine()
    }

    private func recheckDay() {
        appState.reload()
        reflection = appState.journalToday?.text ?? ""
        mood = appState.journalToday?.mood
        routineItems = appState.todayRoutineItems
        withAnimation(.easeInOut(duration: 0.18)) { didRecheckDay = true }
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
                            .frame(minWidth: StillTheme.minimumTapSize, minHeight: StillTheme.minimumTapSize)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.displayName)
                    .accessibilityAddTraits(mood == option ? .isSelected : [])
                }
                Spacer()
                Button("Save") { appState.saveJournal(text: reflection, mood: mood) }
                    .buttonStyle(QuietSecondaryButtonStyle())
            }
            Button("Open Journal") { appState.router.go(to: .journal) }
                .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.accent))
                .accessibilityHint("Opens your private journal and habits.")
        }
        .modifier(NextActionSurface())
    }

    private var roomMoment: some View {
        Button { appState.router.go(to: .sceneCollection) } label: {
            RoomHeroView(sceneName: appState.currentPreset.sceneID.rawValue, sceneID: appState.currentPreset.sceneID,
                         catCoat: appState.preferences.catCoat,
                         catName: appState.catName,
                         catState: CatCompanion.state(
                            isReturningAfterLongAway: appState.isCatExploring,
                            isChangingRoom: appState.isCatExploringNewRoom,
                            hour: Calendar.autoupdatingCurrent.component(.hour, from: appState.container.clock.now)
                         ),
                         allowsCatInteraction: false,
                         plantStage: appState.plantStage, bookCount: appState.books.count,
                         showsControls: false)
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
