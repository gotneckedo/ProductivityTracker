import Foundation

/// Keeps setup short: a person reaches the furnished starter room before any
/// preference questions. The optional questionnaire has one calm invitation
/// after the first completed session, never a recurring prompt or requirement.
enum FirstRunExperience {
    static let maximumOnboardingScreens = 3

    static func offersPersonalization(
        completedSessions: Int,
        goal: OnboardingGoal?,
        breakAppeal: BreakAppeal?
    ) -> Bool {
        completedSessions == 1 && (goal == nil || breakAppeal == nil)
    }
}
