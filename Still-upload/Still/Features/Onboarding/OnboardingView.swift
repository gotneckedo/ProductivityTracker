import SwiftUI

/// A brief privacy-first entry: three screens at most, then the furnished
/// starter room. Optional preferences wait until a person has actually
/// completed one session and remain editable individually from Me.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var step: OnboardingStep

    init() {
        #if DEBUG || STILL_PROOF
        switch DemoLaunch.requestedScreen {
        case "onboarding-privacy":
            _step = State(initialValue: .privacy)
        case "onboarding-room":
            _step = State(initialValue: .starterRoom)
        default:
            _step = State(initialValue: .welcome)
        }
        #else
        _step = State(initialValue: .welcome)
        #endif
    }

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
            .stillScrollableViewport(reservingFloatingTabBar: false)
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
        case .welcome:
            WelcomeIntroduction()
        case .privacy:
            PrivacyIntroduction()
        case .starterRoom:
            StarterRoomIntroduction()
        }
    }

    private var controls: some View {
        Button(step == .starterRoom ? "Enter your room" : "Continue") {
            advance()
        }
        .buttonStyle(QuietPrimaryButtonStyle())
    }

    private func advance() {
        if let next = step.next {
            step = next
        } else {
            // Leave every optional preference unset. The post-first-session
            // invitation owns this choice; Me always offers the editors too.
            appState.completeOnboarding(OnboardingAnswers())
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case privacy
    case starterRoom

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
}

private struct WelcomeIntroduction: View {
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
                Text("A quiet place to begin one thing at a time.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .stillEntrance(delay: 0.1)
        }
    }
}

private struct PrivacyIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
            OnboardingQuestionHeader(
                eyebrow: "Private by default",
                title: "Your focus stays with you.",
                detail: "Still works on this device. There is no account, server, or shared activity feed."
            )
            QuietNote(
                text: "Sessions, tasks, notes, and activity history stay on this device in this version.",
                symbol: "lock"
            )
        }
    }
}

private struct StarterRoomIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
            OnboardingQuestionHeader(
                eyebrow: "Your starter room",
                title: "Everything is ready.",
                detail: "Your furnished Rainy Bedroom and a 25-minute focus session are waiting. You can adjust the details later."
            )
            GlassControlGroup {
                HStack(spacing: StillTheme.Spacing.s) {
                    Image(systemName: "lamp.desk")
                        .font(StillTypography.title2)
                        .foregroundStyle(StillTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(StillTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rainy Bedroom")
                            .font(StillTypography.bodyEmphasis)
                            .foregroundStyle(StillTheme.textPrimary)
                        Text("Start focus in one tap when you arrive.")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                }
            }
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
        }
    }
}

struct DataNotSharedChip: View {
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

struct OnboardingChoiceRow: View {
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

struct PaletteChoiceList: View {
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
            .stillScrollableViewport()
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
