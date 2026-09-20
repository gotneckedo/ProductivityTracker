import SwiftUI

/// One question, then Focus. Nothing else is taught here.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: OnboardingGoal?

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    CalmPlantCanvas(stage: .full)
                        .frame(width: 132, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.large, style: .continuous))
                        .accessibilityHidden(true)
                        .stillEntrance()

                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                        Text("Still")
                            .font(StillTypography.subheadline.weight(.semibold))
                            .foregroundStyle(StillTheme.textSecondary)
                        Text("What would you like help with?")
                            .font(StillTypography.display)
                            .foregroundStyle(StillTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("One question. You can change anything later.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                    .stillEntrance(delay: 0.1)

                    VStack(spacing: StillTheme.Spacing.s) {
                        ForEach(OnboardingGoal.allCases, id: \.self) { goal in
                            GoalChoice(goal: goal, isSelected: selection == goal) {
                                selection = goal
                            }
                        }
                    }
                    .stillEntrance(delay: 0.2)

                    Button("Continue") {
                        if let selection {
                            appState.completeOnboarding(goal: selection)
                        }
                    }
                    .buttonStyle(QuietPrimaryButtonStyle())
                    .disabled(selection == nil)
                    .accessibilityHint(selection == nil ? "Choose an answer first." : "Opens Focus with a 25 minute session ready.")
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.xl)
            }
        }
    }
}

private struct GoalChoice: View {
    let goal: OnboardingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: StillTheme.Spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(StillTypography.bodyEmphasis)
                        .foregroundStyle(StillTheme.textPrimary)
                    Text(goal.detail)
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

#Preview("Onboarding") {
    OnboardingView()
        .environment(PreviewSupport.appState(onboarded: false))
}
