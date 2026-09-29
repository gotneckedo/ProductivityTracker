import XCTest
#if canImport(StillCore)
@testable import StillCore
#else
@testable import Still
#endif

final class RoomAmbientStateTests: XCTestCase {
    func testClockHoursResolveToTheFourRoomAmbientPhases() {
        XCTAssertEqual(RoomAmbientState(hour: 9), .morning)
        XCTAssertEqual(RoomAmbientState(hour: 14), .afternoon)
        XCTAssertEqual(RoomAmbientState(hour: 18), .dusk)
        XCTAssertEqual(RoomAmbientState(hour: 22), .night)
    }

    func testEveryAmbientStateHasAWindowAndDistinctDetailDescription() {
        for state in RoomAmbientState.allCases {
            let description = state.accessibilityDescription.lowercased()
            XCTAssertTrue(description.contains("window") || state == .focus)
            XCTAssertFalse(description.isEmpty)
        }
        XCTAssertNotEqual(RoomAmbientState.morning.accessibilityDescription, RoomAmbientState.dusk.accessibilityDescription)
        XCTAssertNotEqual(RoomAmbientState.afternoon.accessibilityDescription, RoomAmbientState.night.accessibilityDescription)
    }

    func testDesignSystemPhaseNamesRemainForwardCompatible() {
        XCTAssertEqual(RoomAmbientState(dayPhaseName: "dusk"), .dusk)
        XCTAssertEqual(RoomAmbientState(dayPhaseName: "focus"), .focus)
        XCTAssertEqual(RoomAmbientState(dayPhaseName: "future"), .night)
    }
}
