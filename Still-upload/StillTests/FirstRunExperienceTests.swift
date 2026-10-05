import XCTest
#if canImport(StillCore)
@testable import StillCore
#else
@testable import Still
#endif

final class FirstRunExperienceTests: XCTestCase {
    func testFirstRunHasAtMostThreeRequiredScreens() {
        XCTAssertEqual(FirstRunExperience.maximumOnboardingScreens, 3)
    }

    func testOptionalPersonalizationAppearsOnlyAfterFirstCompletionWhenAnswersAreMissing() {
        XCTAssertFalse(FirstRunExperience.offersPersonalization(completedSessions: 0, goal: nil, breakAppeal: nil))
        XCTAssertTrue(FirstRunExperience.offersPersonalization(completedSessions: 1, goal: nil, breakAppeal: nil))
        XCTAssertTrue(FirstRunExperience.offersPersonalization(completedSessions: 1, goal: .focusBetter, breakAppeal: nil))
        XCTAssertFalse(FirstRunExperience.offersPersonalization(completedSessions: 1, goal: .focusBetter, breakAppeal: .quiet))
        XCTAssertFalse(FirstRunExperience.offersPersonalization(completedSessions: 2, goal: nil, breakAppeal: nil))
    }

    func testOpeningFirstSessionPreferencesAcknowledgesCompletionAndUsesMe() {
        let clock = ManualClock(referenceDate)
        let container = DependencyContainer.inMemory(clock: clock, calendar: testCalendar)
        container.preferences.completeOnboarding(OnboardingAnswers())
        let session = container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual).session
        clock.advance(by: minutes(25))
        _ = container.focus.tick()
        let state = AppState(container: container)
        state.bootstrap()

        XCTAssertNotNil(state.router.completion)
        state.openPersonalizationAfterFirstSession()

        XCTAssertNil(state.router.completion)
        XCTAssertEqual(state.router.selectedTab, .me)
        XCTAssertNil(state.preferences.pendingCompletionSessionID)
        XCTAssertEqual(state.completedSessionCount, 1)
        XCTAssertEqual(state.session(session.id)?.state, .completed)
    }
}
