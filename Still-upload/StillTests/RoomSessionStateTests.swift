import XCTest
#if canImport(StillCore)
@testable import StillCore
#else
@testable import Still
#endif

final class RoomSessionStateTests: XCTestCase {
    func testNoLivePhaseKeepsTheRoomIdle() {
        XCTAssertEqual(RoomSessionState(activePhase: nil), .idle)
    }

    func testFocusAndBreakPhasesResolveToDifferentRoomStates() {
        XCTAssertEqual(RoomSessionState(activePhase: .focus), .focusing)
        XCTAssertEqual(RoomSessionState(activePhase: .shortBreak), .breakTime)
        XCTAssertEqual(RoomSessionState(activePhase: .longBreak), .breakTime)
    }

    func testEachRoomStateUsesDistinctCalmDetail() {
        XCTAssertEqual(Set(RoomSessionState.allCases.map(\.visualDetail)).count, RoomSessionState.allCases.count)
        XCTAssertTrue(RoomSessionState.justFinished.accessibilityDescription.lowercased().contains("finished"))
    }
}
