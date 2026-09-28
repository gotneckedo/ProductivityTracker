import XCTest
#if canImport(StillCore)
@testable import StillCore
#else
@testable import Still
#endif

final class CapabilityBoundaryTests: XCTestCase {
    func testMissingAudioCopyNamesTheUnavailableCapabilityWithoutClaimingPlayback() {
        XCTAssertTrue(AmbientAudioCopy.assetsMissing.lowercased().contains("sound files"))
        XCTAssertFalse(AmbientAudioCopy.assetsMissing.lowercased().contains("playing"))
        XCTAssertTrue(AmbientAudioCopy.unavailable.lowercased().contains("isn't available"))
    }

    func testNFCGuideKeepsExternalWritingAndHardwareRequirementsHonest() {
        XCTAssertTrue(FocusCardGuide.steps.joined(separator: " ").lowercased().contains("nfc writing app"))
        XCTAssertTrue(FocusCardGuide.hardwareNote.lowercased().contains("iphone"))
        XCTAssertTrue(FocusCardGuide.hardwareNote.lowercased().contains("simulator"))
    }

    func testUnavailableFamilyControlsFixtureNeverClaimsShielding() {
        let service = UnavailableFocusBlockingService()
        XCTAssertEqual(service.capability, .notAuthorized)
        XCTAssertFalse(service.isShielding)
        XCTAssertEqual(BlockingCopy.title(for: service.capability, isShielding: service.isShielding), "Screen Time permission needed")
        XCTAssertTrue(BlockingCopy.detail(for: service.capability).lowercased().contains("permission"))
    }

    func testMemoryFallbackMessageDoesNotPromisePersistence() {
        let notice = "Storage isn't available right now, so this session won't be saved."
        let container = DependencyContainer.inMemory(storageNotice: notice)
        let state = AppState(container: container)

        XCTAssertEqual(container.storageNotice, notice)
        XCTAssertEqual(state.notice?.text, notice)
        XCTAssertTrue(notice.lowercased().contains("won't be saved"))
    }
}
