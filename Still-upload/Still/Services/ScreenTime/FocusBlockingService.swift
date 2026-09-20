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
    func sessionDidStart(sessionID: UUID, presetID: FocusPresetID, intent: BlockerIntent)
    func sessionDidEnd(sessionID: UUID)
    /// Lifts shields right away, e.g. from "End blocking now".
    func endShieldingNow()
}

extension FocusBlockingService {
    func endShieldingNow() {}
}

/// Opaque, device-specific app selections per preset. The Screen Time
/// selection type is Codable, so the platform layer stores it as `Data`.
protocol BlockingSelectionStore: AnyObject {
    func selectionData(for presetID: FocusPresetID) -> Data?
    func setSelectionData(_ data: Data?, for presetID: FocusPresetID)
}

final class KeyValueBlockingSelectionStore: BlockingSelectionStore {
    private let store: KeyValueStore

    init(store: KeyValueStore) {
        self.store = store
    }

    func selectionData(for presetID: FocusPresetID) -> Data? {
        store.data(forKey: key(presetID))
    }

    func setSelectionData(_ data: Data?, for presetID: FocusPresetID) {
        store.set(data, forKey: key(presetID))
    }

    private func key(_ presetID: FocusPresetID) -> String {
        "still.blocking.selection.\(presetID.rawValue)"
    }
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

    func sessionDidStart(sessionID: UUID, presetID: FocusPresetID, intent: BlockerIntent) {
        recordedIntents[sessionID] = intent
    }

    func sessionDidEnd(sessionID: UUID) {
        recordedIntents[sessionID] = nil
    }
}

// MARK: - FamilyControlsBlockingService

#if canImport(FamilyControls) && canImport(ManagedSettings) && os(iOS)
import FamilyControls
import Foundation
import ManagedSettings

/// Real Screen Time shielding. Used only when `FeatureFlags.appBlocking` is on
/// (see `DependencyContainer.live`), which requires:
/// 1. The Family Controls entitlement (`com.apple.developer.family-controls`)
///    in Still.entitlements. Development builds can use it with a paid
///    account; App Store builds need Apple's approval.
/// 2. The StillShieldMonitor DeviceActivity extension (see
///    FUTURE_CAPABILITIES.md) so shields lift even if Still is closed.
///
/// Each preset keeps its own app/category selection (from
/// `FamilyActivityPicker`), stored as opaque data on this device.
final class FamilyControlsBlockingService: FocusBlockingService {
    static let storeName = ManagedSettingsStore.Name("still.focus")

    private let selections: BlockingSelectionStore
    private let store = ManagedSettingsStore(named: FamilyControlsBlockingService.storeName)
    private(set) var capability: BlockingCapability = .notAuthorized
    private(set) var isShielding = false
    private var shieldedSessionID: UUID?

    init(selections: BlockingSelectionStore) {
        self.selections = selections
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

    /// Call from the Blocking setup screen, never at launch.
    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        refreshAuthorization()
    }

    func selection(for presetID: FocusPresetID) -> FamilyActivitySelection {
        guard let data = selections.selectionData(for: presetID),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    func setSelection(_ selection: FamilyActivitySelection, for presetID: FocusPresetID) {
        selections.setSelectionData(try? JSONEncoder().encode(selection), for: presetID)
    }

    func sessionDidStart(sessionID: UUID, presetID: FocusPresetID, intent: BlockerIntent) {
        refreshAuthorization()
        guard capability == .authorized, intent != .none else { return }
        let selection = selection(for: presetID)
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else {
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        if intent == .strict {
            // Strict also covers websites in the chosen categories.
            store.shield.webDomainCategories = selection.categoryTokens.isEmpty
                ? nil
                : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        }
        shieldedSessionID = sessionID
        isShielding = true
    }

    func sessionDidEnd(sessionID: UUID) {
        guard shieldedSessionID == nil || shieldedSessionID == sessionID else { return }
        endShieldingNow()
    }

    func endShieldingNow() {
        store.clearAllSettings()
        shieldedSessionID = nil
        isShielding = false
    }
}
#endif
