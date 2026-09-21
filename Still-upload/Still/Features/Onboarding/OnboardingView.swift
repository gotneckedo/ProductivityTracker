import SwiftUI

/// Privacy first, then three short, optional questions. Each answer only tunes
/// local defaults and remains individually editable from Me.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var step: OnboardingStep = .privacy
    @State private var goal: OnboardingGoal?
    @State private var breakAppeal: BreakAppeal?
    @State private var palette: AppAccentPalette = .mint

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    progress
                    content
                    controls
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.xl)
            }
        }
    }

    private var progress: some View {
        HStack(spacing: StillTheme.Spacing.xxs) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? StillTheme.accent : StillTheme.border)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .privacy:
            PrivacyIntroduction()
        case .goal:
            OnboardingQuestionHeader(
                eyebrow: "A little about you",
                title: "What would you like help with?",
                detail: "Choose one, or skip it. You can change this later in Me."
            )
            OnboardingChoiceList(options: OnboardingGoal.allCases, selection: $goal)
        case .breakAppeal:
            OnboardingQuestionHeader(
                eyebrow: "Your kind of break",
                title: "What sounds good after focusing?",
                detail: "This only decides what starts near the top of your Break shelf."
            )
            OnboardingChoiceList(options: BreakAppeal.allCases, selection: $breakAppeal)
        case .look:
            OnboardingQuestionHeader(
                eyebrow: "Make it yours",
                title: "Pick a look.",
                detail: "Your accent and Home Screen icon can change together."
            )
            PaletteChoiceList(selection: $palette)
        }
    }

    private var controls: some View {
        VStack(spacing: StillTheme.Spacing.xs) {
            Button(step == .look ? "Begin gently" : "Continue") {
                advance()
            }
            .buttonStyle(QuietPrimaryButtonStyle())

            if step != .privacy {
                Button("Skip this question") {
                    if step == .look { palette = .mint }
                    advance()
                }
                    .buttonStyle(QuietTextButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func advance() {
        if let next = step.next {
            step = next
        } else {
            appState.completeOnboarding(OnboardingAnswers(
                goal: goal,
                breakAppeal: breakAppeal,
                appAccentPalette: palette
            ))
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case privacy
    case goal
    case breakAppeal
    case look

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
}

private struct PrivacyIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
            RoomHeroView(sceneName: "Your room", plantStage: .sprout)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .accessibilityHidden(true)
                .stillEntrance()

            VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                Text("Still")
                    .font(StillTypography.caption)
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(StillTheme.textSecondary)
                Text("Make room for\nwhat matters.")
                    .font(StillTypography.hero)
                    .foregroundStyle(StillTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Processed on this device. No account. No servers.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .stillEntrance(delay: 0.1)

            QuietNote(
                text: "Your setup answers, sessions, tasks, notes, and activity history stay on this device in this version.",
                symbol: "lock"
            )
        }
    }
}

private struct OnboardingQuestionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            Text(eyebrow)
                .font(StillTypography.caption)
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(StillTheme.textSecondary)
            Text(title)
                .font(StillTypography.display)
                .foregroundStyle(StillTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            DataNotSharedChip()
        }
    }
}

private struct DataNotSharedChip: View {
    var body: some View {
        Label("Data not shared", systemImage: "lock.fill")
            .font(StillTypography.caption)
            .foregroundStyle(StillTheme.textSecondary)
            .padding(.horizontal, StillTheme.Spacing.s)
            .frame(minHeight: 34)
            .background(.white.opacity(0.24), in: Capsule())
            .overlay(Capsule().strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline))
            .accessibilityLabel("Data not shared. This answer stays on this device.")
    }
}

private protocol OnboardingChoice: Hashable {
    var title: String { get }
    var detail: String { get }
}

extension OnboardingGoal: OnboardingChoice {}
extension BreakAppeal: OnboardingChoice {}

private struct OnboardingChoiceList<Option: OnboardingChoice>: View {
    let options: [Option]
    @Binding var selection: Option?

    var body: some View {
        VStack(spacing: StillTheme.Spacing.s) {
            ForEach(options, id: \.self) { option in
                OnboardingChoiceRow(
                    title: option.title,
                    detail: option.detail,
                    isSelected: selection == option
                ) {
                    selection = selection == option ? nil : option
                }
            }
        }
    }
}

private struct OnboardingChoiceRow: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: StillTheme.Spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(StillTypography.bodyEmphasis)
                        .foregroundStyle(StillTheme.textPrimary)
                    Text(detail)
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: StillTheme.Spacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(StillTypography.title3)
                    .foregroundStyle(isSelected ? StillTheme.accent : StillTheme.border)
                    .accessibilityHidden(true)
            }
            .padding(StillTheme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                    .fill(isSelected ? StillTheme.accentSoft : StillTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? StillTheme.accent : StillTheme.border, lineWidth: StillTheme.Stroke.hairline)
            )
            .contentShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PaletteChoiceList: View {
    @Binding var selection: AppAccentPalette

    var body: some View {
        VStack(spacing: StillTheme.Spacing.s) {
            ForEach(AppAccentPalette.allCases, id: \.self) { palette in
                Button {
                    selection = palette
                } label: {
                    HStack(spacing: StillTheme.Spacing.s) {
                        Circle()
                            .fill(Color(hex: palette.accentHex))
                            .frame(width: 42, height: 42)
                            .overlay(Circle().strokeBorder(.white.opacity(0.78), lineWidth: 2))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(palette.title)
                                .font(StillTypography.bodyEmphasis)
                                .foregroundStyle(StillTheme.textPrimary)
                            Text(palette.alternateIconName == nil ? "Original app icon" : "Matching alternate app icon")
                                .font(StillTypography.footnote)
                                .foregroundStyle(StillTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: selection == palette ? "checkmark.circle.fill" : "circle")
                            .font(StillTypography.title3)
                            .foregroundStyle(selection == palette ? StillTheme.accent : StillTheme.border)
                            .accessibilityHidden(true)
                    }
                    .padding(StillTheme.Spacing.m)
                    .background(selection == palette ? StillTheme.accentSoft : StillTheme.surface)
                    .stillGlass(radius: StillTheme.Radius.medium)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == palette ? .isSelected : [])
            }
        }
    }
}

/// Reusable editor shown from Me for one answer at a time.
struct OnboardingPreferenceEditorView: View {
    enum Kind {
        case goal
        case breakAppeal
        case look
    }

    @Environment(AppState.self) private var appState
    let kind: Kind

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    DataNotSharedChip()
                    editor
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.l)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var title: String {
        switch kind {
        case .goal: return "Focus goal"
        case .breakAppeal: return "Break preference"
        case .look: return "Look & app icon"
        }
    }

    @ViewBuilder
    private var editor: some View {
        switch kind {
        case .goal:
            Text("What would you like help with?")
                .font(StillTypography.display)
            VStack(spacing: StillTheme.Spacing.s) {
                ForEach(OnboardingGoal.allCases, id: \.self) { goal in
                    OnboardingChoiceRow(title: goal.title, detail: goal.detail, isSelected: appState.preferences.onboardingGoal == goal) {
                        appState.setOnboardingGoal(appState.preferences.onboardingGoal == goal ? nil : goal)
                    }
                }
            }
            Button("Clear answer") { appState.setOnboardingGoal(nil) }
                .buttonStyle(QuietTextButtonStyle())
        case .breakAppeal:
            Text("What sounds good after focusing?")
                .font(StillTypography.display)
            VStack(spacing: StillTheme.Spacing.s) {
                ForEach(BreakAppeal.allCases, id: \.self) { appeal in
                    OnboardingChoiceRow(title: appeal.title, detail: appeal.detail, isSelected: appState.preferences.breakAppeal == appeal) {
                        appState.setBreakAppeal(appState.preferences.breakAppeal == appeal ? nil : appeal)
                    }
                }
            }
            Button("Clear answer") { appState.setBreakAppeal(nil) }
                .buttonStyle(QuietTextButtonStyle())
        case .look:
            Text("Pick a look.")
                .font(StillTypography.display)
            PaletteChoiceList(selection: Binding(
                get: { appState.preferences.appAccentPalette },
                set: { appState.setAppAccentPalette($0) }
            ))
            if !appState.container.preferences.supportsAlternateAppIcons {
                QuietNote(text: "Alternate app icons aren't available on this device. Your palette preference is still saved.")
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environment(PreviewSupport.appState(onboarded: false))
}
