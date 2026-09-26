import SwiftUI

/// A running session is visually quieter than Home: the room dims, controls
/// consolidate into one focus slab, and the tab bar disappears.
struct ActiveFocusView: View {
    @Environment(AppState.self) private var appState
    @State private var isConfirmingEnd = false
    @State private var isConfirmingUnblock = false
    @State private var isAddingNote = false
    @State private var focusNote = ""

    var body: some View {
        Group {
            if let session = appState.activeSession, let snapshot = appState.snapshot {
                content(session: session, snapshot: snapshot)
            } else {
                StillDayPhase.focus.gradient.ignoresSafeArea()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            while !Task.isCancelled {
                await MainActor.run { appState.tick() }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .confirmationDialog(Copy.Focus.endEarlyTitle, isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button(Copy.Focus.endEarlyAction, role: .destructive) { appState.endSessionEarly() }
            Button(Copy.Focus.keepGoing, role: .cancel) {}
        } message: {
            Text(Copy.Focus.endEarlyMessage)
        }
        .confirmationDialog("End blocking for this session?", isPresented: $isConfirmingUnblock, titleVisibility: .visible) {
            Button("End blocking now", role: .destructive) { appState.endBlockingNow() }
            Button("Keep blocking", role: .cancel) {}
        } message: {
            Text("Your apps open again right away. The session keeps going.")
        }
        .sheet(isPresented: $isAddingNote) {
            NavigationStack {
                StillScreen(phase: .focus) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                        Text("A note for this focus session")
                            .font(StillTypography.title)
                            .foregroundStyle(StillDayPhase.focus.ink)
                        TextField("Remember to…", text: $focusNote, axis: .vertical)
                            .font(StillTypography.body)
                            .lineLimit(3...8)
                            .padding(StillTheme.Spacing.s)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
                    }
                    .padding(StillTheme.Spacing.screen)
                }
                .navigationTitle("Focus note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { appState.setFocusNote(focusNote); isAddingNote = false }
                    }
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isAddingNote = false } }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func content(session: FocusSession, snapshot: TimerSnapshot) -> some View {
        let scene = appState.scene(session.sceneID)
        let task = appState.task(session.taskID)
        return StillScreen(phase: .focus) {
            ScrollView {
                VStack(spacing: StillTheme.Spacing.m) {
                    HStack {
                        soundChip(session: session)
                        Button {
                            appState.toggleMute()
                        } label: {
                            Image(systemName: appState.isAudioMuted ? "speaker.slash" : "speaker.wave.2")
                                .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                                .background(.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(appState.isAudioMuted ? "Turn sound on" : "Mute sound")
                        Spacer()
                        Text(scheduleLine(snapshot, now: appState.container.clock.now))
                            .font(StillTypography.caption)
                            .foregroundStyle(StillDayPhase.focus.secondaryInk)
                    }
                    .padding(.top, StillTheme.Spacing.s)

                    RoomHeroView(
                        sceneName: scene.name,
                        sceneID: scene.id,
                        catCoat: appState.preferences.catCoat,
                        catName: appState.catName,
                        catState: CatCompanion.state(
                            isFocusRunning: snapshot.isRunning && !snapshot.phaseKind.isBreak,
                            isBreakPhase: snapshot.phaseKind.isBreak,
                            focusedSeconds: snapshot.totalFocusElapsed,
                            hour: Calendar.autoupdatingCurrent.component(.hour, from: appState.container.clock.now)
                        ),
                        phase: .focus,
                        dimmed: true,
                        plantStage: appState.plantStage,
                        bookCount: 2 + appState.books.count,
                        doodle: appState.doodles.max { $0.updatedAt < $1.updatedAt }?.doodle,
                        placedObjects: appState.placedRoomObjects(in: scene.id)
                    )
                    .aspectRatio(160.0 / 132.0, contentMode: .fit)

                    StillCard(padding: StillTheme.Spacing.l, phase: .focus) {
                        VStack(spacing: StillTheme.Spacing.s) {
                            Text(task?.subject?.name ?? "Focus")
                                .font(StillTypography.caption)
                                .tracking(1.4)
                                .textCase(.uppercase)
                                .foregroundStyle(task?.subject.map { Color(hex: $0.color.hex) } ?? StillDayPhase.focus.secondaryInk)
                            Text(task?.title ?? Copy.Focus.untitledTask)
                                .font(StillTypography.title)
                                .foregroundStyle(StillDayPhase.focus.ink)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            SessionTimerFace(
                                time: timeText(snapshot),
                                caption: caption(snapshot),
                                progress: snapshot.phaseProgress,
                                isPaused: snapshot.isPaused,
                                accessibilityText: spokenState(snapshot),
                                surface: .scene
                            )
                            .padding(.vertical, StillTheme.Spacing.xs)

                            HStack(spacing: StillTheme.Spacing.s) {
                                Button("+5") { appState.addFiveMinutes() }
                                    .buttonStyle(QuietSecondaryButtonStyle(foreground: StillDayPhase.focus.ink, border: StillDayPhase.focus.glassBorder))
                                    .disabled(snapshot.mode != .countdown || snapshot.phaseKind.isBreak)
                                    .accessibilityHint(Copy.Focus.addFiveHint)
                                controlButton(snapshot)
                            }
                        }
                    }

                    if let task {
                        FocusPlanCard(task: task)
                    }

                    if snapshot.isPaused {
                        FocusRescueCard { appState.resume() }
                    }

                    HStack(spacing: StillTheme.Spacing.s) {
                        if appState.isShieldingApps {
                            Button("End blocking") { isConfirmingUnblock = true }
                                .buttonStyle(QuietTextButtonStyle(foreground: StillDayPhase.focus.secondaryInk))
                        } else {
                            Label("No blocking", systemImage: "shield")
                                .font(StillTypography.footnote)
                                .foregroundStyle(StillDayPhase.focus.secondaryInk)
                        }
                        Spacer()
                        Button("+ Note") {
                            focusNote = session.note ?? ""
                            isAddingNote = true
                        }
                        .buttonStyle(QuietTextButtonStyle(foreground: StillDayPhase.focus.secondaryInk))
                        Button("End early") { isConfirmingEnd = true }
                            .buttonStyle(QuietTextButtonStyle(foreground: StillDayPhase.focus.secondaryInk))
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
            }
            .stillScrollableViewport(reservingFloatingTabBar: false)
        }
    }

    @ViewBuilder
    private func controlButton(_ snapshot: TimerSnapshot) -> some View {
        if snapshot.isAwaitingNextPhase {
            Button(snapshot.nextPhaseKind == .focus ? "Start next focus" : "Start break") { appState.startNextPhase() }
                .buttonStyle(QuietPrimaryButtonStyle())
        } else if snapshot.mode == .countUp {
            Button("Finish") { appState.finishCountUp() }
                .buttonStyle(QuietPrimaryButtonStyle())
        } else if snapshot.phaseKind.isBreak {
            Button("Skip break") { appState.skipBreak() }
                .buttonStyle(QuietPrimaryButtonStyle())
        } else {
            Button(snapshot.isPaused ? "Resume" : "Pause") {
                snapshot.isPaused ? appState.resume() : appState.pause()
            }
            .buttonStyle(QuietPrimaryButtonStyle())
            .accessibilityValue(snapshot.isPaused ? "Paused" : "Running")
        }
    }

    private func soundChip(session: FocusSession) -> some View {
        let mix = appState.presets.first { $0.id == session.presetID }?.ambientMix ?? .silent
        return Button {
            appState.router.go(to: .focusConfiguration)
        } label: {
            HStack(spacing: 5) {
                if mix.isSilent {
                    Image(systemName: "speaker.slash")
                } else {
                    SoundBars()
                }
                Text(mix.isSilent ? "Sound off" : mix.summaryLine)
            }
            .font(StillTypography.caption)
            .foregroundStyle(StillDayPhase.focus.ink)
            .padding(.horizontal, StillTheme.Spacing.s)
            .frame(minHeight: StillTheme.minimumTapSize)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(StillDayPhase.focus.glassBorder, lineWidth: StillTheme.Stroke.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mix.isSilent ? "Sound off. Opens soundscape." : "Sound: \(mix.summaryLine). Opens soundscape.")
    }

    private func timeText(_ snapshot: TimerSnapshot) -> String {
        snapshot.remainingInPhase == nil ? DurationFormatter.elapsedClock(snapshot.elapsedInPhase) : DurationFormatter.clock(snapshot.displayedSeconds)
    }

    private func caption(_ snapshot: TimerSnapshot) -> String {
        if snapshot.isAwaitingNextPhase { return snapshot.nextPhaseKind == .focus ? "Ready for the next block" : "Break is ready" }
        if snapshot.isPaused { return "Paused" }
        return snapshot.mode == .pomodoro ? "Focus · \(snapshot.focusBlockNumber) of \(snapshot.focusBlockCount)" : snapshot.phaseKind.displayName
    }

    private func spokenState(_ snapshot: TimerSnapshot) -> String {
        let amount = DurationFormatter.spoken(snapshot.displayedSeconds)
        let base = snapshot.remainingInPhase == nil ? "\(amount) elapsed" : "\(amount) remaining"
        return snapshot.isPaused ? "Paused. \(base)" : base
    }

    private func scheduleLine(_ snapshot: TimerSnapshot, now: Date) -> String {
        guard let end = snapshot.endDate(from: now) else { return snapshot.isPaused ? "Paused" : "" }
        return "Ends \(end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct SoundBars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.45, paused: reduceMotion)) { timeline in
            let step = Int(timeline.date.timeIntervalSinceReferenceDate * 2)
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(StillDayPhase.focus.accent)
                        .frame(width: 2, height: CGFloat(5 + ((step + index * 2) % 4) * 2))
                }
            }
        }
        .frame(width: 12, height: 14)
        .accessibilityHidden(true)
    }
}

private struct FocusPlanCard: View {
    let task: TaskItem
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            Text(Copy.Focus.plan)
                .font(StillTypography.caption)
                .foregroundStyle(StillDayPhase.focus.secondaryInk)
                .textCase(.uppercase)
                .tracking(1.2)
            HStack(spacing: StillTheme.Spacing.s) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(StillDayPhase.focus.accent)
                Text(task.title)
                    .font(StillTypography.callout)
                    .foregroundStyle(StillDayPhase.focus.ink)
                    .lineLimit(2)
            }
            .frame(minHeight: StillTheme.minimumTapSize)
            if !task.steps.isEmpty {
                ForEach(task.steps.prefix(3)) { step in
                    Button { appState.toggleTaskStep(taskID: task.id, stepID: step.id) } label: {
                        HStack(spacing: StillTheme.Spacing.s) {
                            Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.isCompleted ? StillDayPhase.focus.accent : StillDayPhase.focus.secondaryInk)
                            Text(step.title)
                                .font(StillTypography.footnote)
                                .strikethrough(step.isCompleted)
                                .foregroundStyle(StillDayPhase.focus.ink)
                            Spacer()
                        }
                        .frame(minHeight: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(StillTheme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stillGlass(radius: StillTheme.Radius.medium, phase: .focus)
        .accessibilityElement(children: .combine)
    }
}

private struct FocusRescueCard: View {
    let resume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            Text("FOCUS RESCUE · 2 MINUTES")
                .font(StillTypography.caption)
                .tracking(1.1)
                .foregroundStyle(StillDayPhase.focus.secondaryInk)
            Text("A pause is not a failure.")
                .font(StillTypography.title3)
                .foregroundStyle(StillDayPhase.focus.ink)
            Text("Stand up. Take one breath. Drink water if you want. Then decide whether to come back.")
                .font(StillTypography.callout)
                .foregroundStyle(StillDayPhase.focus.secondaryInk)
            Button("I'm back · Resume") { resume() }
                .buttonStyle(QuietSecondaryButtonStyle(foreground: StillDayPhase.focus.ink, border: StillDayPhase.focus.glassBorder))
        }
        .padding(StillTheme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stillGlass(radius: StillTheme.Radius.medium, phase: .focus)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Active focus") {
    FocusTab()
        .environment(PreviewSupport.appState(populated: true, activeSession: true))
}
