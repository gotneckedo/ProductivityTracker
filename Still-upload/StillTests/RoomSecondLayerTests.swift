import XCTest
#if canImport(StillCore)
@testable import StillCore
#else
@testable import Still
#endif

final class RoomSecondLayerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var reference: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9, minute: 30))!
    }

    private func snapshot(
        task: String? = "Outline biology notes",
        books: [String] = ["The Secret Garden", "Anne of Green Gables"],
        plant: PlantGrowthStage = .leafy
    ) -> RoomSecondLayerSnapshot {
        let week = (0..<7).map { offset in
            RoomSecondLayerDay(
                day: calendar.date(byAdding: .day, value: offset - 6, to: reference)!,
                focusDuration: offset.isMultiple(of: 2) ? 25 * 60 : 0
            )
        }
        return RoomSecondLayerSnapshot(
            selectedTaskTitle: task,
            books: books,
            plantStage: plant,
            windowPhaseName: "morning",
            totalFocus: 95 * 60,
            weeklyFocus: week,
            now: reference,
            calendar: calendar
        )
    }

    func testEveryRoomObjectHasASecondLayerFact() {
        let snapshot = snapshot()
        let facts = RoomSecondLayerTarget.allCases.map(snapshot.fact(for:))

        XCTAssertEqual(facts.count, 7)
        XCTAssertEqual(Set(facts.map(\.target)), Set(RoomSecondLayerTarget.allCases))
        XCTAssertTrue(facts.allSatisfy { !$0.detail.isEmpty && !$0.supportingDetail.isEmpty })
    }

    func testDeskBooksAndPlantUseExistingLocalData() {
        let snapshot = snapshot()

        XCTAssertTrue(snapshot.fact(for: .desk).detail.contains("Outline biology notes"))
        XCTAssertTrue(snapshot.fact(for: .books).supportingDetail.contains("The Secret Garden"))
        XCTAssertTrue(snapshot.fact(for: .plant).detail.contains("leafy"))
        XCTAssertTrue(snapshot.fact(for: .plant).supportingDetail.contains("never wilts"))
    }

    func testWindowLampClockAndCalendarRemainObservational() {
        let snapshot = snapshot()

        XCTAssertTrue(snapshot.fact(for: .window).detail.contains("Morning"))
        XCTAssertEqual(snapshot.fact(for: .lamp).detail, "Honey warmth")
        XCTAssertTrue(snapshot.fact(for: .clock).supportingDetail.contains("1 h 35 min"))
        XCTAssertTrue(snapshot.fact(for: .calendar).detail.contains("last 7 days"))
        XCTAssertTrue(snapshot.fact(for: .calendar).supportingDetail.contains("Mon"))
    }

    func testEmptyDeskAndBookShelfStayKindAndUsable() {
        let snapshot = snapshot(task: nil, books: [], plant: .sprout)

        XCTAssertEqual(snapshot.fact(for: .desk).detail, "The desk is clear.")
        XCTAssertTrue(snapshot.fact(for: .books).supportingDetail.contains("No books"))
        XCTAssertTrue(snapshot.fact(for: .plant).detail.contains("sprout"))
    }
}
