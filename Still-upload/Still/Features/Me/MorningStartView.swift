import SwiftUI

/// A gentle morning notification that opens Still with a session ready.
/// It's a notification, not an alarm: it follows silent mode and Focus.
struct MorningStartView: View {
    @Environment(AppState.self) private var appState
    @State private var plan = MorningStartPlan.standard
    @State private var hasLoaded = false

    private let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Morning Start")
                            .font(StillTypography.display)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("A quiet nudge at the start of the day: pick one task, and a session is ready when you are.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    StillCard {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                            Toggle("Morning Start", isOn: $plan.isEnabled)
                                .font(StillTypography.bodyEmphasis)
                            if plan.isEnabled {
                                Divider()
                                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                                    .font(StillTypography.body)
                                Divider()
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                                    Text("Days")
                                        .font(StillTypography.body)
                                        .foregroundStyle(StillTheme.textPrimary)
                                    HStack(spacing: StillTheme.Spacing.xxs) {
                                        ForEach(1...7, id: \.self) { weekday in
                                            dayToggle(weekday)
                                        }
                                    }
                                }
                                Divider()
                                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                                    Text("Session")
                                        .font(StillTypography.body)
                                        .foregroundStyle(StillTheme.textPrimary)
                                    PresetChips(presets: appState.presets, selectedID: plan.presetID) { id in
                                        plan.presetID = id
                                    }
                                }
                            }
                        }
                    }

                    if plan.isEnabled {
                        Text(plan.summary)
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    }

                    QuietNote(text: "This is a notification, so it follows silent mode and Focus. A true alarm that rings through silent mode needs AlarmKit and is planned for later.", symbol: "bell")
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            plan = appState.preferences.morningStart
            hasLoaded = true
        }
        .onChange(of: plan) { _, newValue in
            guard hasLoaded, newValue != appState.preferences.morningStart else { return }
            appState.setMorningStart(newValue)
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = plan.hour
                components.minute = plan.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                plan.hour = components.hour ?? plan.hour
                plan.minute = components.minute ?? plan.minute
            }
        )
    }

    private func dayToggle(_ weekday: Int) -> some View {
        let isOn = plan.weekdays.contains(weekday)
        return Button {
            if isOn {
                plan.weekdays.remove(weekday)
            } else {
                plan.weekdays.insert(weekday)
            }
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

#Preview("Morning Start") {
    NavigationStack {
        MorningStartView()
    }
    .environment(PreviewSupport.appState())
}
