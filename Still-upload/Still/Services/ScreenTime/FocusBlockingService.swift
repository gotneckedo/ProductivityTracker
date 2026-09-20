import Foundation

enum BlockingCapability: Equatable {
    /// V1: intent is recorded, nothing is shielded.
    case simulationOnly
    /// The Family Controls entitlement is present but authorization was not granted.
    case notAuthorized
    /// Family Controls authorized; shielding can be applied (V2).
    case authorized
}

/// Boundary for Screen Time shielding.
///
/// Real shielding needs the Family Controls entitlement (approved by Apple),
/// user authorization, and a persisted app/category selection. Until then the
/// app uses `MockFocusBlockingService`, and the UI must say so honestly.
protocol FocusBlockingService: AnyObject {
    var capability: BlockingCapability { get }
    /// True only when the operating system is actually shielding apps.
    var isShielding: Bool { get }
    func sessionDidStart(sessionID: UUID, intent: BlockerIntent)
    func sessionDidEnd(sessionID: UUID)
}

/// User-facing blocking language. Never claims apps are blocked unless the
/// device is really shielding them.
enum BlockingCopy {
    static func title(for capability: BlockingCapability, isShielding: Bool) -> String {
        switch capability {
        case .simulationOnly: return "Blocking setup is ready"
        case .notAuthorized: return "Screen Time permission needed"
        case .authorized: return isShielding ? "Apps are shielded" : "Blocking is available"
        }
    }

    static func detail(for capability: BlockingCapability) -> String {
        switch capability {
        case .simulationOnly:
            return "Presets remember what you'd like to block. App shielding arrives in a later version, after Apple approves Screen Time access. Nothing is blocked today."
        case .notAuthorized:
            return "Still needs Screen Time permission before it can shield apps."
        case .authorized:
            return "Shielding follows your preset while a session runs."
        }
    }
}

/// SIMULATION ONLY. Records the requested intent and never shields anything.
/// `isShielding` is always false so no screen can claim apps are blocked.
final class MockFocusBlockingService: FocusBlockingService {
    let capability: BlockingCapability = .simulationOnly
    let isShielding = false
    private(set) var recordedIntents: [UUID: BlockerIntent] = [:]

    func sessionDidStart(sessionID: UUID, intent: BlockerIntent) {
        recordedIntents[sessionID] = intent
    }

    func sessionDidEnd(sessionID: UUID) {
        recordedIntents[sessionID] = nil
    }
}

// MARK: - FamilyControlsBlockingService

#if canImport(FamilyControls) && os(iOS)
import FamilyControls
import Foundation

/// V2 scaffold for real Screen Time shielding. NOT used in V1: the container
/// injects `MockFocusBlockingService` until `FeatureFlags.appBlocking` is on.
///
/// Compiles without the entitlement; it only fails at runtime if called
/// without it. Before enabling:
/// 1. Request the Family Controls (Distribution) entitlement from Apple and add
///    `com.apple.developer.family-controls` to Still.entitlements.
/// 2. TODO(V2-authorization): call `requestAuthorization()` from a calm,
///    explained setup screen (never at launch).
/// 3. TODO(V2-selection): present `FamilyActivityPicker`, then persist the
///    `FamilyActivitySelection` (it is Codable) per preset.
/// 4. TODO(V2-shielding): import ManagedSettings and, in `sessionDidStart`,
///    apply `ManagedSettingsStore(named:)` shields for the preset's selection;
///    clear them in `sessionDidEnd`. Add a DeviceActivity monitor extension so
///    shields lift even if the app is killed.
/// 5. TODO(V2-override): add an emergency override that ends shielding and
///    records a local audit event.
final class FamilyControlsBlockingService: FocusBlockingService {
    private(set) var capability: BlockingCapability = .notAuthorized
    /// Stays false until shielding is really applied (TODO(V2-shielding)).
    private(set) var isShielding = false

    init() {
        refreshAuthorization()
    }

    func refreshAuthorization() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            capability = .authorized
        default:
            capability = .notAuthorized
        }
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refreshAuthorization()
    }

    func sessionDidStart(sessionID: UUID, intent: BlockerIntent) {
        guard capability == .authorized, intent != .none else { return }
        // TODO(V2-shielding): apply ManagedSettingsStore shields here, then set isShielding = true.
    }

    func sessionDidEnd(sessionID: UUID) {
        // TODO(V2-shielding): clear ManagedSettingsStore shields here.
        isShielding = false
    }
}
#endif
