import SwiftUI

/// Focus begins with an inhabited room and one immediate action. The lower card
/// overlaps the room edge so the environment remains the visual lead instead of
/// becoming a small decorative header.
struct FocusHomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let preset = appState.currentPreset
        let scene = displayScene(for: preset)
        StillScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                        ZStack(alignment: .bottom) {
                            RoomHeroView(
                                sceneName: scene.name,
                                sceneID: scene.id,
                                catCoat: appState.preferences.catCoat,
                                plantStage: appState.plantStage,
                                bookCount: 2 + appState.books.count,
                                doodle: appState.doodles.max { $0.updatedAt < $1.updatedAt }?.doodle,
                                placedObjects: appState.placedRoomObjects(in: scene.id),
                                onPrevious: { cycleScene(from: preset, direction: -1) },
                                onNext: { cycleScene(from: preset, direction: 1) },
                                onRoomTarget: open,
                                showsRoomLabels: focusDayCount < 3
                            )
                            .aspectRatio(160.0 / 132.0, contentMode: .fit)

                            focusActionCard(preset: preset)
                                .padding(.horizontal, StillTheme.Spacing.xs)
                                .offset(y: 78)
                        }
                        .padding(.bottom, 72)
                        .stillEntrance()

                        header(scene: scene)

                        Button {
                            appState.router.go(to: .roomCollection)
                        } label: {
                            HStack(spacing: StillTheme.Spacing.s) {
                                Image(systemName: "shippingbox")
                                    .foregroundStyle(StillTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Copy.Home.yourThings)
                                        .font(StillTypography.bodyEmphasis)
                                        .foregroundStyle(StillTheme.textPrimary)
                                    Text(Copy.Home.yourThingsHint)
                                        .font(StillTypography.footnote)
                                        .foregroundStyle(StillTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(StillTheme.textTertiary)
                            }
                            .padding(StillTheme.Spacing.s)
                            .stillGlass(radius: StillTheme.Radius.medium)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens your earned room objects and placement slots.")

                        if let unlocked = appState.newlyUnlockedScenes.first {
                            QuietNote(text: "\(unlocked.name) is open now. Visit it whenever you like.", symbol: "sparkles")
                        }
                        if appState.audioStatus == .assetsMissing && !preset.ambientMix.isSilent {
                            QuietNote(text: AmbientAudioCopy.assetsMissing)
                        }
                        Color.clear.frame(height: 1).id("focus-home-bottom")
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.top, StillTheme.Spacing.s)
                }
                .stillScrollableViewport()
                .onAppear {
                    #if DEBUG
                    guard DemoLaunch.shouldScrollToBottom("home") else { return }
                    DispatchQueue.main.async { proxy.scrollTo("focus-home-bottom", anchor: .bottom) }
                    #endif
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func header(scene: SceneDefinition) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
            Text(Calendar.autoupdatingCurrent.component(.hour, from: .now) < 12 ? Copy.Home.morningGreeting : Copy.Home.readyGreeting)
                .font(StillTypography.display)
                .foregroundStyle(StillTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(Copy.Home.roomDetail(scene.name))
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func focusActionCard(preset: FocusPreset) -> some View {
        StillCard(padding: StillTheme.Spacing.m) {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                HomeTaskLine(task: appState.selectedTask, emphasized: appState.personalization.emphasizesTasks) {
                    appState.router.go(to: .tasks)
                }

                Button {
                    appState.startFocus()
                } label: {
                    Text(Copy.Home.startFocus(DurationFormatter.short(preset.timer.focusDuration)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(QuietPrimaryButtonStyle())
                .accessibilityHint("Starts \(DurationFormatter.short(preset.timer.focusDuration)) of focus.")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: StillTheme.Spacing.xs) {
                        optionPill(title: preset.name, symbol: "timer")
                        optionPill(title: preset.ambientMix.isSilent ? "Sound off" : preset.ambientMix.summaryLine, symbol: preset.ambientMix.isSilent ? "speaker.slash" : "speaker.wave.1")
                        optionPill(title: preset.blockerIntent == .none ? "No blocking" : "Blocking", symbol: "shield")
                    }
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                        optionPill(title: preset.name, symbol: "timer")
                        optionPill(title: preset.ambientMix.isSilent ? "Sound off" : preset.ambientMix.summaryLine, symbol: preset.ambientMix.isSilent ? "speaker.slash" : "speaker.wave.1")
                        optionPill(title: preset.blockerIntent == .none ? "No blocking" : "Blocking", symbol: "shield")
                    }
                }
            }
        }
    }

    private func optionPill(title: String, symbol: String) -> some View {
        Button {
            appState.router.go(to: .focusConfiguration)
        } label: {
            Label(title, systemImage: symbol)
                .font(StillTypography.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(StillTheme.textSecondary)
                .padding(.horizontal, StillTheme.Spacing.s)
                .frame(minHeight: StillTheme.minimumTapSize)
                .background(.white.opacity(0.18), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.45), lineWidth: StillTheme.Stroke.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens session options.")
    }

    private func displayScene(for preset: FocusPreset) -> SceneDefinition {
        let scene = appState.scene(preset.sceneID)
        return appState.isUnlocked(scene) ? scene : SceneCatalog.rainyBedroom
    }

    private func cycleScene(from preset: FocusPreset, direction: Int) {
        let available = SceneCatalog.all.filter { appState.isUnlocked($0) }
        guard !available.isEmpty else { return }
        let currentIndex = available.firstIndex { $0.id == preset.sceneID } ?? 0
        let nextIndex = (currentIndex + direction + available.count) % available.count
        var edited = preset
        edited.sceneID = available[nextIndex].id
        edited.renderMode = .scene
        appState.savePreset(edited)
    }

    private var focusDayCount: Int {
        Set(appState.sessions.filter { $0.state == .completed }.map {
            Calendar.autoupdatingCurrent.startOfDay(for: $0.endedAt ?? $0.startedAt)
        }).count
    }

    private func open(_ hotspot: RoomHotspot) {
        switch hotspot {
        case .desk:
            appState.router.go(to: .tasks)
        case .shelf:
            appState.router.go(to: .breakShelf)
        case .calendar:
            appState.router.go(to: .today)
        case .plant:
            appState.router.go(to: .me)
        case .window:
            appState.router.go(to: .sceneCollection)
        }
    }
}

private struct HomeTaskLine: View {
    let task: TaskItem?
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: StillTheme.Spacing.s) {
                Circle()
                    .fill(subjectColor)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task?.title ?? (emphasized ? Copy.Home.addHomework : Copy.Home.chooseTask))
                        .font(StillTypography.bodyEmphasis)
                        .foregroundStyle(StillTheme.textPrimary)
                        .lineLimit(2)
                    Text(task?.subject.map { "\($0.name) · \(Copy.Home.taskReady)" } ?? Copy.Home.optionalTask)
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: StillTheme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(StillTypography.footnote.weight(.semibold))
                    .foregroundStyle(StillTheme.textTertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens today's tasks.")
    }

    private var subjectColor: Color {
        guard let task else { return StillTheme.textTertiary.opacity(0.45) }
        return task.subject.map { Color(hex: $0.color.hex) } ?? StillTheme.accent
    }
}

/// "25 min" with a plain description of the timer underneath.
struct DurationSummary: View {
    let timer: TimerConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
            Text(headline)
                .font(StillTypography.display.monospacedDigit())
                .foregroundStyle(StillTheme.textPrimary)
            Text(detail)
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        timer.mode == .countUp ? "Open-ended" : DurationFormatter.short(timer.focusDuration)
    }

    private var detail: String {
        switch timer.mode {
        case .countdown: return "Countdown"
        case .countUp: return "Count up. Finish whenever you're ready."
        case .pomodoro: return "Pomodoro · \(timer.focusBlockCount) blocks"
        }
    }
}

#Preview("Focus home") {
    FocusHomeView()
        .environment(PreviewSupport.appState(populated: true))
}

#Preview("Focus home · Large text") {
    FocusHomeView()
        .environment(PreviewSupport.appState(populated: true))
        .dynamicTypeSize(.accessibility2)
}
