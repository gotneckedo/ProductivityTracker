import SwiftUI

/// Complete Wake up planning UI. Delivery remains the real iOS 17 local
/// notification fallback until the AlarmKit boundary is implemented and tested.
struct MorningStartView: View {
    @Environment(AppState.self) private var appState
    @State private var wakeUp = WakeUpPlan.standard
    @State private var hasLoaded = false

    private let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                            Text(appState.container.flags.wakeUpPreview ? "Wake up" : "Morning Start")
                                .font(StillTypography.display)
                                .foregroundStyle(StillTheme.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text("A quiet nudge at the start of the day: pick one task, and a session is ready when you are.")
                                .font(StillTypography.callout)
                                .foregroundStyle(StillTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if appState.container.flags.wakeUpPreview { PreviewTag() }
                    }

                    StillCard {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                            Toggle(appState.container.flags.wakeUpPreview ? "Wake up plan" : "Morning Start",
                                   isOn: $wakeUp.schedule.isEnabled)
                                .font(StillTypography.bodyEmphasis)
                            Group {
                                Divider()
                                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                                    .font(StillTypography.body)
                                Divider()
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                                    Text("Days")
                                        .font(StillTypography.body)
                                        .foregroundStyle(StillTheme.textPrimary)
                                    HStack(spacing: StillTheme.Spacing.xxs) {
                                        ForEach(1...7, id: \.self) { weekday in dayToggle(weekday) }
                                    }
                                }
                                Divider()
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                                    Text("Preset to queue")
                                        .font(StillTypography.body)
                                    PresetChips(presets: appState.presets, selectedID: wakeUp.schedule.presetID) { id in
                                        wakeUp.schedule.presetID = id
                                    }
                                }
                                Divider()
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                                    HStack {
                                        Text("Stop with")
                                            .font(StillTypography.body)
                                        if appState.container.flags.wakeUpPreview { PreviewTag() }
                                    }
                                    SelectionPill(options: WakeUpStopMethod.allCases, selection: $wakeUp.stopWith) { $0.displayName }
                                    Text(stopMethodDetail)
                                        .font(StillTypography.footnote)
                                        .foregroundStyle(StillTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .opacity(wakeUp.schedule.isEnabled ? 1 : 0.5)
                            .disabled(!wakeUp.schedule.isEnabled)
                        }
                    }

                    if wakeUp.schedule.isEnabled {
                        Text(wakeUp.schedule.summary)
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    deliveryNote

                    if appState.container.flags.wakeUpPreview {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            SectionHeader(title: "Try the hand-off", detail: "Local simulation only; it does not start or dismiss a system alarm.")
                            Button("Simulate Still opening") { appState.simulateWakeUpOpening() }
                                .buttonStyle(QuietSecondaryButtonStyle())
                            if appState.container.wakeUp.isWaitingForFocusCard {
                                Button("Simulate Focus Card tap") { appState.simulateWakeUpCardTap() }
                                    .buttonStyle(QuietPrimaryButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
            .stillScrollableViewport()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            wakeUp = WakeUpPlan(schedule: appState.preferences.morningStart,
                                stopWith: appState.preferences.wakeUpStopMethod)
            hasLoaded = true
        }
        .onChange(of: wakeUp) { _, newValue in
            guard hasLoaded else { return }
            if appState.container.flags.wakeUpPreview {
                appState.setWakeUp(newValue)
            } else if newValue.schedule != appState.preferences.morningStart {
                appState.setMorningStart(newValue.schedule)
            }
        }
    }

    @ViewBuilder
    private var deliveryNote: some View {
        switch appState.container.wakeUp.delivery {
        case .notificationFallback, .previewNotificationFallback:
            QuietNote(
                text: "On iOS 17–25, this is a local notification. It follows silent mode and Focus and can be dismissed normally. AlarmKit is the planned real-alarm backend.",
                symbol: "bell"
            )
        case .alarmKit:
            QuietNote(
                text: "The system owns the alarm controls. Focus Card mode can make Still wait after opening, but it cannot prevent the system alarm from being dismissed.",
                symbol: "alarm"
            )
        }
    }

    private var stopMethodDetail: String {
        switch wakeUp.stopWith {
        case .button:
            return "When Still opens, the queued session is ready right away."
        case .focusCard:
            return "After Still opens, the queued session and morning checklist wait for a card tap. The system alarm can still be dismissed with its own controls."
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = wakeUp.schedule.hour
                components.minute = wakeUp.schedule.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                wakeUp.schedule.hour = components.hour ?? wakeUp.schedule.hour
                wakeUp.schedule.minute = components.minute ?? wakeUp.schedule.minute
            }
        )
    }

    private func dayToggle(_ weekday: Int) -> some View {
        let isOn = wakeUp.schedule.weekdays.contains(weekday)
        return Button {
            if isOn { wakeUp.schedule.weekdays.remove(weekday) }
            else { wakeUp.schedule.weekdays.insert(weekday) }
        } label: {
            Text(weekdayLetters[weekday - 1])
                .font(StillTypography.callout.weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? StillTheme.onAccent : StillTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().fill(isOn ? StillTheme.accent : Color.white.opacity(0.10)))
                .overlay(Circle().strokeBorder(isOn ? StillTheme.accent : StillTheme.border, lineWidth: StillTheme.Stroke.hairline))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekdayNames[weekday - 1])
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Wake up") {
    NavigationStack { MorningStartView() }
        .environment(PreviewSupport.appState())
}
